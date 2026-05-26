extends RefCounted
class_name IAPManager

# Thin wrapper around the GodotGooglePlayBilling addon.
#
# Goals:
#   - Safe to instantiate on ANY platform (Windows/headless/Android). Non-Android
#     platforms get a stub that returns "unlock available" only when the host
#     code sets a debug-unlock flag — production paywalls stay closed.
#   - One product (the $9.99 lifetime unlock) by default; the SKU is a constant
#     so it's easy to find when configuring the Play Console.
#   - Persists the "unlocked" verdict locally so the app launches offline
#     without re-querying Play every time.
#
# Usage:
#   var iap := IAPManager.new()
#   iap.setup()
#   iap.purchase_made.connect(func(): _grant_unlock())
#   iap.start_purchase(IAPManager.UNLOCK_PRODUCT_ID)
#
# Replace UNLOCK_PRODUCT_ID with the actual Play Console product ID before
# release. Keep it lowercase, alphanumeric+dot, matching Play Console.

signal purchase_made
signal purchase_failed(reason: String)
signal product_details_loaded(details: Dictionary)

# Product ID configured in Google Play Console for the one-time unlock SKU.
# Change this string to match whatever you set up in the Play Console.
# Do NOT include "$", "9.99", or pricing — Play attaches that. Just the
# identifier the store will look up.
const UNLOCK_PRODUCT_ID := "clefira.lifetime_unlock"

# Storage key for the "we've confirmed unlock" verdict. Keeps a local copy so
# offline app launches don't need a Play round-trip.
const UNLOCK_PERSIST_PATH := "user://iap_unlock.json"

# The BillingClient autoload class from the addon. Loaded lazily so this
# module is harmless to instantiate on Windows.
var _billing = null  # type: BillingClient | null
var _last_purchase_token: String = ""
var _unlock_confirmed: bool = false


func setup() -> bool:
	# Returns true if Play Billing is available and ready to negotiate.
	# Returns false on desktop or when the plugin isn't loaded — caller can
	# branch to a "purchase not available on this platform" UI message.
	if not OS.has_feature("android"):
		return false
	# Lazy-load the BillingClient class so non-Android platforms never touch
	# the JNI singleton (which doesn't exist there).
	var BillingClient = load("res://addons/GodotGooglePlayBilling/BillingClient.gd")
	if BillingClient == null:
		push_warning("[IAP] BillingClient.gd not found — plugin not installed?")
		return false
	_billing = BillingClient.new()
	if _billing == null:
		return false
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(_on_disconnected)
	_billing.connect_error.connect(_on_connect_error)
	_billing.query_product_details_response.connect(_on_query_product_details_response)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.acknowledge_purchase_response.connect(_on_acknowledge_purchase_response)
	_billing.query_purchases_response.connect(_on_query_purchases_response)
	_load_local_unlock()
	_billing.start_connection()
	return true


# Returns true if the user has paid + the unlock is confirmed locally.
# Caller should gate paid features behind this check.
func is_unlocked() -> bool:
	return _unlock_confirmed


# Initiates the in-app purchase flow on Play. Caller listens for
# `purchase_made` (success) or `purchase_failed` (cancelled/declined).
func start_purchase(product_id: String = UNLOCK_PRODUCT_ID) -> void:
	if _billing == null:
		purchase_failed.emit("not_available")
		return
	if _billing.get_connection_state() != _billing.ConnectionState.CONNECTED:
		purchase_failed.emit("not_connected")
		return
	var result: Dictionary = _billing.purchase(product_id)
	if int(result.get("response_code", 0)) != _billing.BillingResponseCode.OK:
		purchase_failed.emit("flow_error:%d" % int(result.get("response_code", 0)))


# Re-checks Play for previously-completed purchases (e.g. user reinstalls
# the app). Call on startup AFTER setup() so the unlock state syncs from
# Play before the user sees the home screen.
func restore_purchases() -> void:
	if _billing == null:
		return
	if _billing.get_connection_state() != _billing.ConnectionState.CONNECTED:
		return
	_billing.query_purchases(_billing.ProductType.INAPP)


# --- Internal: signal handlers ---


func _on_connected() -> void:
	# Once connected, immediately query the product details so the paywall UI
	# can show actual localized pricing, and check for prior purchases.
	if _billing == null:
		return
	_billing.query_product_details(
		PackedStringArray([UNLOCK_PRODUCT_ID]),
		_billing.ProductType.INAPP
	)
	_billing.query_purchases(_billing.ProductType.INAPP)


func _on_disconnected() -> void:
	pass


func _on_connect_error(response_code: int, debug_message: String) -> void:
	push_warning("[IAP] connect_error code=%d msg=%s" % [response_code, debug_message])


func _on_query_product_details_response(response: Dictionary) -> void:
	var products_v: Variant = response.get("product_details_list", null)
	if typeof(products_v) != TYPE_ARRAY or (products_v as Array).is_empty():
		return
	# Surface the first matching product so the paywall UI can render
	# localized pricing (price string + currency code) from Play.
	for prod in products_v:
		if typeof(prod) != TYPE_DICTIONARY:
			continue
		if str((prod as Dictionary).get("product_id", "")) == UNLOCK_PRODUCT_ID:
			product_details_loaded.emit(prod)
			return


func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	if code != _billing.BillingResponseCode.OK:
		# USER_CANCELED is common and benign — just emit a failure for the UI.
		purchase_failed.emit("response_code:%d" % code)
		return
	var purchases_v: Variant = response.get("purchases", null)
	if typeof(purchases_v) != TYPE_ARRAY:
		return
	for p in purchases_v:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		_consume_or_acknowledge(p as Dictionary)


# Lifetime unlock is non-consumable → acknowledge ONLY (never consume).
# If you later add a consumable SKU (e.g. coin pack), branch on product_id.
func _consume_or_acknowledge(purchase: Dictionary) -> void:
	var state: int = int(purchase.get("purchase_state", 0))
	if state != _billing.PurchaseState.PURCHASED:
		return  # PENDING (e.g. gift card waiting on family approval) — leave alone.
	var token := str(purchase.get("purchase_token", ""))
	if token.is_empty():
		return
	_last_purchase_token = token
	if not bool(purchase.get("is_acknowledged", false)):
		_billing.acknowledge_purchase(token)
	# Acknowledge response handler will flip the unlock flag.
	# But if it's already acknowledged from a prior session, grant immediately.
	if bool(purchase.get("is_acknowledged", false)):
		_grant_unlock(token)


func _on_acknowledge_purchase_response(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	if code != _billing.BillingResponseCode.OK:
		push_warning("[IAP] acknowledge failed code=%d" % code)
		return
	_grant_unlock(_last_purchase_token)


func _on_query_purchases_response(response: Dictionary) -> void:
	# Same data shape as on_purchase_updated — reuse the handler.
	var code: int = int(response.get("response_code", -1))
	if code != _billing.BillingResponseCode.OK:
		return
	var purchases_v: Variant = response.get("purchases", null)
	if typeof(purchases_v) != TYPE_ARRAY:
		return
	for p in purchases_v:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		_consume_or_acknowledge(p as Dictionary)


# --- Local persistence ---


func _grant_unlock(token: String) -> void:
	if _unlock_confirmed:
		return  # idempotent
	_unlock_confirmed = true
	var f := FileAccess.open(UNLOCK_PERSIST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"unlocked": true,
			"token_hash": token.sha256_text(),  # store hash, not raw token
			"unlocked_at": Time.get_unix_time_from_system(),
		}))
		f.close()
	purchase_made.emit()


func _load_local_unlock() -> void:
	if not FileAccess.file_exists(UNLOCK_PERSIST_PATH):
		return
	var f := FileAccess.open(UNLOCK_PERSIST_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_unlock_confirmed = bool((parsed as Dictionary).get("unlocked", false))
