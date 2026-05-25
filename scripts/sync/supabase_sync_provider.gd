extends "res://scripts/sync/sync_provider.gd"
class_name SupabaseSyncProvider

# Supabase implementation of the SyncProvider interface (Tier A: snapshot-based
# backup/restore). Uses GoTrue REST for auth and PostgREST for the snapshots
# table. All network calls go through HTTPRequest child nodes that this Node
# owns and frees per-call — no shared connection state to mishandle.
#
# Auth flow:
#   1. send_magic_link(email) → POST /auth/v1/otp { email, create_user: true }
#   2. User receives email containing a 6-digit code (Supabase default email
#      template includes {{ .Token }} — verify the template if you customised it).
#   3. verify_otp(email, "123456") → POST /auth/v1/verify { email, token, type: "email" }
#      → returns { access_token, refresh_token, user: { id, email } }
#   4. Cached locally; refreshed on demand when nearing expiry.

const SyncConfigScript = preload("res://scripts/sync/sync_config.gd")

# --- Session state ---
var _access_token: String = ""
var _refresh_token: String = ""
var _access_token_expires_at: int = 0  # unix seconds
var _user_id: String = ""
var _user_email: String = ""
var _pending_email: String = ""  # email awaiting OTP verification

# Snapshot freshness state — used to decide whether a pull-on-launch should
# surface a "newer snapshot from another device" prompt.
#   _last_pushed_at — created_at of the most recent successful push from this device.
#   _last_pulled_at — created_at of the most recent snapshot this device restored.
#   _last_seen_cloud_at / _last_seen_cloud_snapshot_id — the cloud snapshot the
#     user explicitly acknowledged (either by restoring or by clicking "Skip").
# A cloud snapshot is "newer" iff its created_at is strictly greater than
# max(all three above). String compare on ISO 8601 timestamps is correct.
var _last_pushed_at: String = ""
var _last_pulled_at: String = ""
var _last_seen_cloud_at: String = ""
var _last_seen_cloud_snapshot_id: String = ""

# Pending newer-snapshot info — populated by check_for_newer_snapshot when it
# finds something, cleared after restore or skip. The dialog reads this on
# show_dialog() so the banner survives closing/reopening the dialog.
var _pending_newer_at: String = ""
var _pending_newer_label: String = ""
var _pending_newer_id: String = ""


func _ready() -> void:
	_load_cached_session()
	if _user_id.is_empty() or _refresh_token.is_empty():
		return  # Not signed in — nothing to refresh, no signal to emit.
	# Silent token refresh at launch. We always refresh on launch so the user
	# never hits an expired access token mid-action. If the refresh token is
	# itself dead (revoked / >30 days old), clear the session and emit
	# session_refresh_failed so the UI prompts for re-sign-in.
	_refresh_then(Callable(self, "_on_launch_refresh_succeeded"), Callable(self, "_on_launch_refresh_failed"))


func _on_launch_refresh_succeeded() -> void:
	session_restored.emit(_user_id, _user_email)


func _on_launch_refresh_failed(error: String) -> void:
	# The cached refresh token can't be exchanged — treat as signed out.
	_clear_session_and_emit()
	session_refresh_failed.emit(error)


# =============================================================================
# Public API — auth
# =============================================================================

func send_magic_link(email: String) -> void:
	_pending_email = email.strip_edges().to_lower()
	if _pending_email.is_empty():
		magic_link_failed.emit("Email cannot be empty.")
		return
	var body := JSON.stringify({
		"email": _pending_email,
		"create_user": true,
	})
	_perform_request(
		HTTPClient.METHOD_POST,
		SyncConfigScript.AUTH_OTP_PATH,
		_anon_headers(),
		body,
		Callable(self, "_on_magic_link_response"),
	)


func verify_otp(email: String, token: String) -> void:
	var clean_email: String = email.strip_edges().to_lower()
	var clean_token: String = token.strip_edges()
	if clean_email.is_empty() or clean_token.is_empty():
		sign_in_failed.emit("Email and code are both required.")
		return
	var body := JSON.stringify({
		"email": clean_email,
		"token": clean_token,
		"type": "email",
	})
	_perform_request(
		HTTPClient.METHOD_POST,
		SyncConfigScript.AUTH_VERIFY_PATH,
		_anon_headers(),
		body,
		Callable(self, "_on_verify_response"),
	)


func sign_out() -> void:
	if _refresh_token.is_empty():
		_clear_session_and_emit()
		return
	# Best-effort server-side logout. We always clear the local session
	# regardless of the response — local state is what matters for the user.
	_perform_request(
		HTTPClient.METHOD_POST,
		SyncConfigScript.AUTH_LOGOUT_PATH,
		_authed_headers(),
		"",
		Callable(self, "_on_logout_response"),
	)


# =============================================================================
# Public API — snapshots
# =============================================================================

func push_snapshot(bundle: Dictionary, device_label: String) -> void:
	if not is_signed_in():
		snapshot_push_failed.emit("Not signed in.")
		return
	# Ensure the access token is fresh before the call. If refresh is needed
	# and fails, we forward the auth error to the snapshot signal so the
	# caller knows why the push didn't happen.
	if _access_token_expiring_soon():
		_refresh_then(Callable(self, "_do_push_snapshot").bind(bundle, device_label), Callable(self, "_on_refresh_failed_for_push"))
	else:
		_do_push_snapshot(bundle, device_label)


func pull_latest_snapshot() -> void:
	if not is_signed_in():
		snapshot_pull_failed.emit("Not signed in.")
		return
	if _access_token_expiring_soon():
		_refresh_then(Callable(self, "_do_pull_snapshot"), Callable(self, "_on_refresh_failed_for_pull"))
	else:
		_do_pull_snapshot()


# Pull-on-launch helper: fetches the latest snapshot's METADATA only (no apply)
# and emits newer_snapshot_available iff the server has something newer than
# this device knows about. Quiet when there's nothing new — no failure signal.
func check_for_newer_snapshot() -> void:
	if not is_signed_in():
		return
	if _access_token_expiring_soon():
		_refresh_then(Callable(self, "_do_check_snapshot"), Callable(self, "_on_refresh_failed_for_check"))
	else:
		_do_check_snapshot()


func acknowledge_newer_snapshot_skipped() -> void:
	# Treat the pending snapshot as "I've seen this, don't prompt me again".
	# Bumps the last-seen marker so a yet-newer snapshot would still re-prompt.
	if _pending_newer_at.is_empty():
		return
	_last_seen_cloud_at = _pending_newer_at
	_last_seen_cloud_snapshot_id = _pending_newer_id
	_pending_newer_at = ""
	_pending_newer_label = ""
	_pending_newer_id = ""
	_save_cached_session()


func has_pending_newer_snapshot() -> bool:
	return not _pending_newer_at.is_empty()


func pending_newer_snapshot_info() -> Dictionary:
	if _pending_newer_at.is_empty():
		return {}
	return {
		"created_at": _pending_newer_at,
		"device_label": _pending_newer_label,
		"snapshot_id": _pending_newer_id,
	}


func last_pushed_at() -> String:
	return _last_pushed_at


func last_pulled_at() -> String:
	return _last_pulled_at


# =============================================================================
# Session inspection
# =============================================================================

func is_signed_in() -> bool:
	return not _user_id.is_empty() and not _refresh_token.is_empty()


func current_user_id() -> String:
	return _user_id


func current_user_email() -> String:
	return _user_email


# =============================================================================
# Internal — HTTP plumbing
# =============================================================================

# Builds the standard "anon-only" header set (used for unauthenticated calls
# such as the OTP request and OTP verify).
func _anon_headers() -> Array:
	return [
		"apikey: " + SyncConfigScript.SUPABASE_ANON_KEY,
		"Content-Type: application/json",
		"Accept: application/json",
	]


# Bearer-token headers for authenticated calls (REST + logout).
func _authed_headers() -> Array:
	return [
		"apikey: " + SyncConfigScript.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + _access_token,
		"Content-Type: application/json",
		"Accept: application/json",
	]


# Fires a single HTTP request and routes the response to `callback`, then
# disposes of the HTTPRequest node. callback signature: (ok: bool, response_code: int, body_text: String).
func _perform_request(method: int, path: String, headers: Array, body: String, callback: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = SyncConfigScript.HTTP_TIMEOUT_SECONDS
	add_child(req)
	var hp: PackedStringArray = PackedStringArray()
	for h in headers:
		hp.append(str(h))
	var on_completed := func(result: int, response_code: int, _resp_headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var body_text: String = response_body.get_string_from_utf8()
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
		callback.call(ok, response_code, body_text)
		req.queue_free()
	req.request_completed.connect(on_completed, CONNECT_ONE_SHOT)
	var err := req.request(SyncConfigScript.SUPABASE_URL + path, hp, method, body)
	if err != OK:
		req.queue_free()
		callback.call(false, 0, "HTTPRequest error %d" % err)


# Tries to parse an error message out of the Supabase JSON response body. Falls
# back to "HTTP <code>" when the body isn't JSON or doesn't contain a known
# error field.
func _extract_error_message(response_code: int, body_text: String) -> String:
	var prefix := "HTTP %d" % response_code
	var parsed: Variant = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in ["error_description", "msg", "message", "error"]:
			if parsed.has(key):
				return "%s: %s" % [prefix, str(parsed[key])]
	if response_code == 0:
		return body_text if not body_text.is_empty() else "Network error"
	return prefix


# =============================================================================
# Internal — auth response handlers
# =============================================================================

func _on_magic_link_response(ok: bool, response_code: int, body_text: String) -> void:
	if ok:
		magic_link_sent.emit(_pending_email)
	else:
		magic_link_failed.emit(_extract_error_message(response_code, body_text))


func _on_verify_response(ok: bool, response_code: int, body_text: String) -> void:
	if not ok:
		sign_in_failed.emit(_extract_error_message(response_code, body_text))
		return
	var parsed: Variant = JSON.parse_string(body_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		sign_in_failed.emit("Could not parse auth response.")
		return
	if not _apply_session_response(parsed):
		sign_in_failed.emit("Auth response missing access_token / refresh_token.")
		return
	_save_cached_session()
	signed_in.emit(_user_id, _user_email)


func _on_logout_response(_ok: bool, _response_code: int, _body_text: String) -> void:
	# We deliberately ignore the response — local clear is always what matters.
	_clear_session_and_emit()


# Refresh-token swap helpers.
func _access_token_expiring_soon() -> bool:
	if _access_token.is_empty():
		return true
	var now: int = int(Time.get_unix_time_from_system())
	return _access_token_expires_at - now < SyncConfigScript.ACCESS_TOKEN_REFRESH_MARGIN_SECONDS


func _refresh_then(on_success: Callable, on_failure: Callable) -> void:
	if _refresh_token.is_empty():
		on_failure.call("No refresh token; please sign in again.")
		return
	var body := JSON.stringify({"refresh_token": _refresh_token})
	var handler := func(ok: bool, response_code: int, body_text: String) -> void:
		if not ok:
			on_failure.call(_extract_error_message(response_code, body_text))
			return
		var parsed: Variant = JSON.parse_string(body_text)
		if typeof(parsed) != TYPE_DICTIONARY or not _apply_session_response(parsed):
			on_failure.call("Refresh response missing tokens.")
			return
		_save_cached_session()
		on_success.call()
	_perform_request(
		HTTPClient.METHOD_POST,
		SyncConfigScript.AUTH_REFRESH_PATH,
		_anon_headers(),
		body,
		handler,
	)


func _on_refresh_failed_for_push(error: String) -> void:
	snapshot_push_failed.emit("Could not refresh session: %s" % error)


func _on_refresh_failed_for_pull(error: String) -> void:
	snapshot_pull_failed.emit("Could not refresh session: %s" % error)


func _on_refresh_failed_for_check(_error: String) -> void:
	# check_for_newer_snapshot is silent — failing the refresh here just means
	# we'll try again on the next launch. Don't surface anything to the UI.
	pass


# =============================================================================
# Internal — snapshot calls
# =============================================================================

func _do_push_snapshot(bundle: Dictionary, device_label: String) -> void:
	# PostgREST insert: include Prefer: return=representation so we get the row
	# (including its generated id + created_at) back in the response body.
	var headers: Array = _authed_headers()
	headers.append("Prefer: return=representation")
	var row := {
		"user_id": _user_id,
		"device_label": device_label,
		"payload_json": bundle,
	}
	var body := JSON.stringify(row)
	_perform_request(
		HTTPClient.METHOD_POST,
		SyncConfigScript.REST_SNAPSHOTS_PATH,
		headers,
		body,
		Callable(self, "_on_push_response"),
	)


func _on_push_response(ok: bool, response_code: int, body_text: String) -> void:
	if not ok:
		snapshot_push_failed.emit(_extract_error_message(response_code, body_text))
		return
	var parsed: Variant = JSON.parse_string(body_text)
	# PostgREST returns an array for inserts (even with one row).
	if typeof(parsed) == TYPE_ARRAY and parsed.size() > 0:
		var first: Dictionary = parsed[0]
		var created_at: String = str(first.get("created_at", ""))
		_last_pushed_at = created_at if not created_at.is_empty() else _last_pushed_at
		# Pushing this device's snapshot inherently means we know about its
		# version — clear any pending "newer snapshot" prompt for older rows.
		if not _pending_newer_at.is_empty() and (_last_pushed_at >= _pending_newer_at):
			_pending_newer_at = ""
			_pending_newer_label = ""
			_pending_newer_id = ""
		_save_cached_session()
		snapshot_pushed.emit(str(first.get("id", "")), created_at)
		return
	snapshot_pushed.emit("", "")


func _do_pull_snapshot() -> void:
	# Latest snapshot for the signed-in user; RLS guarantees we never see others'.
	var path: String = SyncConfigScript.REST_SNAPSHOTS_PATH + "?select=*&order=created_at.desc&limit=1"
	_perform_request(
		HTTPClient.METHOD_GET,
		path,
		_authed_headers(),
		"",
		Callable(self, "_on_pull_response"),
	)


func _on_pull_response(ok: bool, response_code: int, body_text: String) -> void:
	if not ok:
		snapshot_pull_failed.emit(_extract_error_message(response_code, body_text))
		return
	var parsed: Variant = JSON.parse_string(body_text)
	if typeof(parsed) != TYPE_ARRAY:
		snapshot_pull_failed.emit("Unexpected pull response shape.")
		return
	if parsed.is_empty():
		snapshot_pull_failed.emit("No snapshots found on the server yet.")
		return
	var row: Dictionary = parsed[0]
	var payload_v: Variant = row.get("payload_json", {})
	if typeof(payload_v) != TYPE_DICTIONARY:
		snapshot_pull_failed.emit("Snapshot payload is not an object.")
		return
	var created_at: String = str(row.get("created_at", ""))
	# Successful restore from this snapshot acknowledges it across the board.
	_last_pulled_at = created_at if not created_at.is_empty() else _last_pulled_at
	_last_seen_cloud_at = created_at
	_last_seen_cloud_snapshot_id = str(row.get("id", ""))
	_pending_newer_at = ""
	_pending_newer_label = ""
	_pending_newer_id = ""
	_save_cached_session()
	snapshot_pulled.emit(payload_v, created_at, str(row.get("device_label", "")))


# Metadata-only fetch used by check_for_newer_snapshot. Reuses the snapshots
# REST endpoint but reads `select=id,device_label,created_at` to avoid pulling
# the full payload_json bytes — keeps launch fast even with big snapshots.
func _do_check_snapshot() -> void:
	var path: String = SyncConfigScript.REST_SNAPSHOTS_PATH + "?select=id,device_label,created_at&order=created_at.desc&limit=1"
	_perform_request(
		HTTPClient.METHOD_GET,
		path,
		_authed_headers(),
		"",
		Callable(self, "_on_check_response"),
	)


func _on_check_response(ok: bool, _response_code: int, body_text: String) -> void:
	if not ok:
		return  # silent: check is best-effort
	var parsed: Variant = JSON.parse_string(body_text)
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty():
		return  # no snapshots yet; nothing to prompt about
	var row: Dictionary = parsed[0]
	var cloud_at: String = str(row.get("created_at", ""))
	if cloud_at.is_empty():
		return
	# "Newer" iff strictly greater than every local marker. String compare on
	# ISO 8601 is correct because the format is fixed-width-ish + zero-padded.
	if not _is_strictly_newer(cloud_at):
		return
	_pending_newer_at = cloud_at
	_pending_newer_label = str(row.get("device_label", ""))
	_pending_newer_id = str(row.get("id", ""))
	_save_cached_session()
	newer_snapshot_available.emit(_pending_newer_at, _pending_newer_label, _pending_newer_id)


func _is_strictly_newer(cloud_at: String) -> bool:
	if cloud_at <= _last_pushed_at:
		return false
	if cloud_at <= _last_pulled_at:
		return false
	if cloud_at <= _last_seen_cloud_at:
		return false
	return true


# =============================================================================
# Internal — session persistence
# =============================================================================

# Reads token + user fields out of a GoTrue auth response into instance state.
# Returns true when the response contained the required fields.
func _apply_session_response(resp: Dictionary) -> bool:
	var access: String = str(resp.get("access_token", ""))
	var refresh: String = str(resp.get("refresh_token", ""))
	if access.is_empty() or refresh.is_empty():
		return false
	_access_token = access
	_refresh_token = refresh
	var expires_in: int = int(resp.get("expires_in", 3600))
	_access_token_expires_at = int(Time.get_unix_time_from_system()) + expires_in
	var user_v: Variant = resp.get("user", {})
	if typeof(user_v) == TYPE_DICTIONARY:
		_user_id = str(user_v.get("id", _user_id))
		_user_email = str(user_v.get("email", _user_email))
	return true


func _save_cached_session() -> void:
	var f := FileAccess.open(SyncConfigScript.SESSION_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"access_token": _access_token,
		"refresh_token": _refresh_token,
		"expires_at": _access_token_expires_at,
		"user_id": _user_id,
		"user_email": _user_email,
		"last_pushed_at": _last_pushed_at,
		"last_pulled_at": _last_pulled_at,
		"last_seen_cloud_at": _last_seen_cloud_at,
		"last_seen_cloud_snapshot_id": _last_seen_cloud_snapshot_id,
		"pending_newer_at": _pending_newer_at,
		"pending_newer_label": _pending_newer_label,
		"pending_newer_id": _pending_newer_id,
	}, "\t"))
	f.close()


func _load_cached_session() -> void:
	if not FileAccess.file_exists(SyncConfigScript.SESSION_PATH):
		return
	var f := FileAccess.open(SyncConfigScript.SESSION_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_access_token = str(parsed.get("access_token", ""))
	_refresh_token = str(parsed.get("refresh_token", ""))
	_access_token_expires_at = int(parsed.get("expires_at", 0))
	_user_id = str(parsed.get("user_id", ""))
	_user_email = str(parsed.get("user_email", ""))
	_last_pushed_at = str(parsed.get("last_pushed_at", ""))
	_last_pulled_at = str(parsed.get("last_pulled_at", ""))
	_last_seen_cloud_at = str(parsed.get("last_seen_cloud_at", ""))
	_last_seen_cloud_snapshot_id = str(parsed.get("last_seen_cloud_snapshot_id", ""))
	_pending_newer_at = str(parsed.get("pending_newer_at", ""))
	_pending_newer_label = str(parsed.get("pending_newer_label", ""))
	_pending_newer_id = str(parsed.get("pending_newer_id", ""))


func _clear_session_and_emit() -> void:
	_access_token = ""
	_refresh_token = ""
	_access_token_expires_at = 0
	_user_id = ""
	_user_email = ""
	_last_pushed_at = ""
	_last_pulled_at = ""
	_last_seen_cloud_at = ""
	_last_seen_cloud_snapshot_id = ""
	_pending_newer_at = ""
	_pending_newer_label = ""
	_pending_newer_id = ""
	if FileAccess.file_exists(SyncConfigScript.SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SyncConfigScript.SESSION_PATH))
	signed_out.emit()
