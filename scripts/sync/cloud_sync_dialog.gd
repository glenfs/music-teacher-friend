extends Control
class_name CloudSyncDialog

# Self-contained modal dialog for cloud sync. Three UI states share one panel:
#   STATE_SIGNED_OUT  — email entry + "Send Code" button
#   STATE_CODE_SENT   — OTP code entry + "Verify" button
#   STATE_SIGNED_IN   — status + push/pull/sign-out buttons
#
# Owner code (teacher_dashboard.gd) calls set_sync_provider() once, then
# show_dialog() / hide_dialog() as needed. All sync_provider signals are
# routed into per-state status text — the dialog never crashes the dashboard.

const SyncBundleScript = preload("res://scripts/sync/sync_bundle.gd")

enum State { SIGNED_OUT, CODE_SENT, SIGNED_IN }

var _sync_provider: Node = null
var _state: int = State.SIGNED_OUT
var _last_synced_at: String = ""
var _busy: bool = false

# Cached widget references — built once in _build_ui().
var _backdrop: ColorRect
var _panel: PanelContainer
var _close_btn: Button
var _title_label: Label

# State: SIGNED_OUT
var _so_panel: VBoxContainer
var _so_email_input: LineEdit
var _so_send_btn: Button
var _so_status: Label

# State: CODE_SENT
var _cs_panel: VBoxContainer
var _cs_caption: Label
var _cs_code_input: LineEdit
var _cs_verify_btn: Button
var _cs_back_btn: Button
var _cs_status: Label

# State: SIGNED_IN
var _si_panel: VBoxContainer
var _si_account_label: Label
var _si_push_btn: Button
var _si_pull_btn: Button
var _si_signout_btn: Button
var _si_status: Label

# Newer-snapshot conflict banner inside SIGNED_IN (shown when the provider
# has a pending newer snapshot from another device).
var _nb_panel: PanelContainer
var _nb_label: Label
var _nb_restore_btn: Button
var _nb_skip_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_as_relative = false
	z_index = 700  # above the teacher dashboard (which sits below modal band)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_state()


# Called by the dashboard right after instantiation. Wires our handlers to the
# provider's signals so the dialog reflects every async result.
func set_sync_provider(provider: Node) -> void:
	if _sync_provider == provider:
		return
	_sync_provider = provider
	if _sync_provider == null:
		return
	_sync_provider.connect("magic_link_sent", Callable(self, "_on_magic_link_sent"))
	_sync_provider.connect("magic_link_failed", Callable(self, "_on_magic_link_failed"))
	_sync_provider.connect("signed_in", Callable(self, "_on_signed_in"))
	_sync_provider.connect("sign_in_failed", Callable(self, "_on_sign_in_failed"))
	_sync_provider.connect("signed_out", Callable(self, "_on_signed_out"))
	_sync_provider.connect("snapshot_pushed", Callable(self, "_on_snapshot_pushed"))
	_sync_provider.connect("snapshot_push_failed", Callable(self, "_on_snapshot_push_failed"))
	_sync_provider.connect("snapshot_pulled", Callable(self, "_on_snapshot_pulled"))
	_sync_provider.connect("snapshot_pull_failed", Callable(self, "_on_snapshot_pull_failed"))
	_sync_provider.connect("session_restored", Callable(self, "_on_session_restored"))
	if _sync_provider.has_signal("newer_snapshot_available"):
		_sync_provider.connect("newer_snapshot_available", Callable(self, "_on_newer_snapshot_available"))
	if _sync_provider.has_signal("session_refresh_failed"):
		_sync_provider.connect("session_refresh_failed", Callable(self, "_on_session_refresh_failed"))
	if _sync_provider.call("is_signed_in"):
		_state = State.SIGNED_IN
		_refresh_state()


func show_dialog() -> void:
	visible = true
	move_to_front()
	if _sync_provider != null and _sync_provider.call("is_signed_in"):
		_state = State.SIGNED_IN
	elif _state == State.CODE_SENT and _sync_provider != null and _sync_provider.call("current_user_id") == "":
		# Returning to a CODE_SENT state after closing/reopening is fine; keep it.
		pass
	else:
		_state = State.SIGNED_OUT
	_refresh_state()


func hide_dialog() -> void:
	visible = false


# =============================================================================
# UI BUILD
# =============================================================================

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 360)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.15, 0.22, 1.0)
	sb.border_color = Color(0.32, 0.56, 0.78, 1.0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_panel.add_child(content)

	# --- Header row ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	_title_label = Label.new()
	_title_label.text = "☁  Cloud Sync"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(36, 32)
	_close_btn.pressed.connect(hide_dialog)
	header.add_child(_close_btn)

	# --- SIGNED_OUT panel ---
	_so_panel = VBoxContainer.new()
	_so_panel.add_theme_constant_override("separation", 10)
	content.add_child(_so_panel)
	var so_intro := Label.new()
	so_intro.text = "Sign in to back up your students' data and access it on another device. Enter your email — we'll send a 6-digit code."
	so_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	so_intro.add_theme_color_override("font_color", Color(0.80, 0.88, 0.94, 0.92))
	_so_panel.add_child(so_intro)
	_so_email_input = LineEdit.new()
	_so_email_input.placeholder_text = "you@example.com"
	_so_email_input.custom_minimum_size = Vector2(0, 36)
	_so_panel.add_child(_so_email_input)
	_so_send_btn = Button.new()
	_so_send_btn.text = "Send Sign-in Code"
	_so_send_btn.custom_minimum_size = Vector2(0, 40)
	_so_send_btn.pressed.connect(_on_send_otp_pressed)
	_so_panel.add_child(_so_send_btn)
	_so_status = _make_status_label()
	_so_panel.add_child(_so_status)

	# --- CODE_SENT panel ---
	_cs_panel = VBoxContainer.new()
	_cs_panel.add_theme_constant_override("separation", 10)
	content.add_child(_cs_panel)
	_cs_caption = Label.new()
	_cs_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cs_caption.add_theme_color_override("font_color", Color(0.80, 0.88, 0.94, 0.92))
	_cs_panel.add_child(_cs_caption)
	_cs_code_input = LineEdit.new()
	_cs_code_input.placeholder_text = "6-digit code"
	_cs_code_input.max_length = 6
	_cs_code_input.custom_minimum_size = Vector2(0, 36)
	_cs_panel.add_child(_cs_code_input)
	var cs_buttons := HBoxContainer.new()
	cs_buttons.add_theme_constant_override("separation", 10)
	_cs_panel.add_child(cs_buttons)
	_cs_back_btn = Button.new()
	_cs_back_btn.text = "← Use Different Email"
	_cs_back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cs_back_btn.pressed.connect(_on_back_to_email_pressed)
	cs_buttons.add_child(_cs_back_btn)
	_cs_verify_btn = Button.new()
	_cs_verify_btn.text = "Verify Code"
	_cs_verify_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cs_verify_btn.pressed.connect(_on_verify_otp_pressed)
	cs_buttons.add_child(_cs_verify_btn)
	_cs_status = _make_status_label()
	_cs_panel.add_child(_cs_status)

	# --- SIGNED_IN panel ---
	_si_panel = VBoxContainer.new()
	_si_panel.add_theme_constant_override("separation", 10)
	content.add_child(_si_panel)
	_si_account_label = Label.new()
	_si_account_label.add_theme_color_override("font_color", Color(0.80, 0.94, 0.86, 0.96))
	_si_account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_si_panel.add_child(_si_account_label)

	# Newer-snapshot conflict banner — shown only when provider reports one.
	# A separate panel inside SIGNED_IN, gold/orange-tinted so it reads as
	# "decision required" without being alarming.
	_nb_panel = PanelContainer.new()
	var nb_sb := StyleBoxFlat.new()
	nb_sb.bg_color = Color(0.32, 0.22, 0.08, 0.92)
	nb_sb.border_color = Color(0.96, 0.78, 0.32, 1.0)
	nb_sb.border_width_left = 2
	nb_sb.border_width_top = 2
	nb_sb.border_width_right = 2
	nb_sb.border_width_bottom = 2
	nb_sb.corner_radius_top_left = 8
	nb_sb.corner_radius_top_right = 8
	nb_sb.corner_radius_bottom_left = 8
	nb_sb.corner_radius_bottom_right = 8
	nb_sb.content_margin_left = 14
	nb_sb.content_margin_right = 14
	nb_sb.content_margin_top = 12
	nb_sb.content_margin_bottom = 12
	_nb_panel.add_theme_stylebox_override("panel", nb_sb)
	_nb_panel.visible = false
	_si_panel.add_child(_nb_panel)
	var nb_box := VBoxContainer.new()
	nb_box.add_theme_constant_override("separation", 8)
	_nb_panel.add_child(nb_box)
	_nb_label = Label.new()
	_nb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nb_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74, 1.0))
	nb_box.add_child(_nb_label)
	var nb_buttons := HBoxContainer.new()
	nb_buttons.add_theme_constant_override("separation", 10)
	nb_box.add_child(nb_buttons)
	_nb_skip_btn = Button.new()
	_nb_skip_btn.text = "Skip for now"
	_nb_skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nb_skip_btn.pressed.connect(_on_newer_banner_skip_pressed)
	nb_buttons.add_child(_nb_skip_btn)
	_nb_restore_btn = Button.new()
	_nb_restore_btn.text = "Restore from cloud"
	_nb_restore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nb_restore_btn.pressed.connect(_on_newer_banner_restore_pressed)
	nb_buttons.add_child(_nb_restore_btn)

	_si_push_btn = Button.new()
	_si_push_btn.text = "☁ Sync Now (push to cloud)"
	_si_push_btn.custom_minimum_size = Vector2(0, 40)
	_si_push_btn.pressed.connect(_on_sync_push_pressed)
	_si_panel.add_child(_si_push_btn)
	_si_pull_btn = Button.new()
	_si_pull_btn.text = "⬇ Restore from Cloud (replaces local)"
	_si_pull_btn.custom_minimum_size = Vector2(0, 40)
	_si_pull_btn.pressed.connect(_on_sync_pull_pressed)
	_si_panel.add_child(_si_pull_btn)
	_si_signout_btn = Button.new()
	_si_signout_btn.text = "Sign Out"
	_si_signout_btn.custom_minimum_size = Vector2(0, 32)
	_si_signout_btn.pressed.connect(_on_sync_sign_out_pressed)
	_si_panel.add_child(_si_signout_btn)
	_si_status = _make_status_label()
	_si_panel.add_child(_si_status)


func _make_status_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96, 0.85))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = ""
	return l


# =============================================================================
# STATE MANAGEMENT
# =============================================================================

func _refresh_state() -> void:
	_so_panel.visible = _state == State.SIGNED_OUT
	_cs_panel.visible = _state == State.CODE_SENT
	_si_panel.visible = _state == State.SIGNED_IN
	# Reflect signed-in account info when applicable.
	if _state == State.SIGNED_IN and _sync_provider != null:
		var email: String = str(_sync_provider.call("current_user_email"))
		var stamp: String = "" if _last_synced_at.is_empty() else "  ·  last synced %s" % _last_synced_at
		_si_account_label.text = "Signed in as %s%s" % [email, stamp]
		_refresh_newer_snapshot_banner()
	_set_busy(_busy)


# Re-reads the provider's pending newer-snapshot state and shows / hides the
# conflict banner accordingly. Safe to call any time the dialog might be visible.
func _refresh_newer_snapshot_banner() -> void:
	if _nb_panel == null:
		return
	if _sync_provider == null or not _sync_provider.call("has_pending_newer_snapshot"):
		_nb_panel.visible = false
		return
	var info: Dictionary = _sync_provider.call("pending_newer_snapshot_info")
	var who: String = str(info.get("device_label", ""))
	if who.is_empty():
		who = "another device"
	var when_str: String = str(info.get("created_at", ""))
	_nb_label.text = "There's a newer snapshot in the cloud from %s (uploaded %s). Restoring will replace your local data." % [who, when_str]
	_nb_panel.visible = true


func _set_busy(busy: bool) -> void:
	_busy = busy
	_so_send_btn.disabled = busy
	_cs_verify_btn.disabled = busy
	_cs_back_btn.disabled = busy
	_si_push_btn.disabled = busy
	_si_pull_btn.disabled = busy
	_si_signout_btn.disabled = busy
	if _nb_restore_btn != null:
		_nb_restore_btn.disabled = busy
		_nb_skip_btn.disabled = busy


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_send_otp_pressed() -> void:
	if _sync_provider == null:
		return
	var email := _so_email_input.text.strip_edges()
	if email.is_empty() or not email.contains("@"):
		_so_status.text = "Please enter a valid email address."
		return
	_so_status.text = "Sending code to %s..." % email
	_set_busy(true)
	_sync_provider.call("send_magic_link", email)


func _on_verify_otp_pressed() -> void:
	if _sync_provider == null:
		return
	var code := _cs_code_input.text.strip_edges()
	var email := _so_email_input.text.strip_edges()
	if code.is_empty():
		_cs_status.text = "Enter the 6-digit code from your email."
		return
	_cs_status.text = "Verifying code..."
	_set_busy(true)
	_sync_provider.call("verify_otp", email, code)


func _on_back_to_email_pressed() -> void:
	_state = State.SIGNED_OUT
	_cs_code_input.text = ""
	_cs_status.text = ""
	_refresh_state()


func _on_sync_push_pressed() -> void:
	if _sync_provider == null:
		return
	_si_status.text = "Bundling local data..."
	_set_busy(true)
	var bundle: Dictionary = SyncBundleScript.collect()
	var label: String = SyncBundleScript.default_device_label()
	_si_status.text = "Uploading snapshot (%d files)..." % int((bundle.get("files", {}) as Dictionary).size())
	_sync_provider.call("push_snapshot", bundle, label)


func _on_sync_pull_pressed() -> void:
	if _sync_provider == null:
		return
	_si_status.text = "Fetching latest snapshot..."
	_set_busy(true)
	_sync_provider.call("pull_latest_snapshot")


func _on_sync_sign_out_pressed() -> void:
	if _sync_provider == null:
		return
	_si_status.text = "Signing out..."
	_set_busy(true)
	_sync_provider.call("sign_out")


# =============================================================================
# SYNC PROVIDER SIGNAL HANDLERS
# =============================================================================

func _on_magic_link_sent(email: String) -> void:
	_state = State.CODE_SENT
	_cs_caption.text = "We sent a 6-digit code to %s. Check your email (it may take a minute) and enter the code below." % email
	_cs_status.text = ""
	_cs_code_input.text = ""
	_set_busy(false)
	_refresh_state()


func _on_magic_link_failed(error: String) -> void:
	_set_busy(false)
	_so_status.text = "Could not send code. %s" % error


func _on_signed_in(_user_id: String, _email: String) -> void:
	_state = State.SIGNED_IN
	_set_busy(false)
	_si_status.text = "Signed in. You can now push or pull your data."
	_refresh_state()


func _on_session_restored(_user_id: String, _email: String) -> void:
	# Auto-resume on next launch when a cached session was loaded from disk.
	_state = State.SIGNED_IN
	_refresh_state()


func _on_sign_in_failed(error: String) -> void:
	_set_busy(false)
	_cs_status.text = "Verification failed. %s" % error


func _on_signed_out() -> void:
	_state = State.SIGNED_OUT
	_set_busy(false)
	_last_synced_at = ""
	_so_email_input.text = ""
	_so_status.text = "Signed out."
	_refresh_state()


func _on_snapshot_pushed(_snapshot_id: String, created_at: String) -> void:
	_set_busy(false)
	_last_synced_at = created_at if not created_at.is_empty() else Time.get_datetime_string_from_system(true, true)
	_si_status.text = "✓ Snapshot pushed. Saved at %s." % _last_synced_at
	_refresh_state()


func _on_snapshot_push_failed(error: String) -> void:
	_set_busy(false)
	_si_status.text = "Push failed. %s" % error


func _on_snapshot_pulled(bundle: Dictionary, created_at: String, device_label: String) -> void:
	# Safety: snapshot the current local state to user://sync_backups/ BEFORE we
	# overwrite anything. If a bad cloud snapshot ever lands here, the teacher
	# has a recoverable copy of the pre-restore state.
	var backup_path: String = SyncBundleScript.snapshot_local_to_backup("pre_restore")
	# Apply the bundle to disk, then surface the result.
	_si_status.text = "Restoring %d files from snapshot..." % int((bundle.get("files", {}) as Dictionary).size())
	var result: Dictionary = SyncBundleScript.apply(bundle)
	_set_busy(false)
	if bool(result.get("ok", false)):
		_last_synced_at = created_at if not created_at.is_empty() else Time.get_datetime_string_from_system(true, true)
		var src: String = "another device" if device_label.is_empty() else device_label
		var backup_hint: String = ""
		if backup_path != "":
			backup_hint = "\nLocal backup saved to %s before restore." % backup_path
		_si_status.text = "✓ Restored %d files from %s (saved at %s). Restart the app to fully reload.%s" % [int(result.get("written", 0)), src, _last_synced_at, backup_hint]
	else:
		var errs: Array = result.get("errors", [])
		_si_status.text = "Partial restore (%d files). Errors: %s" % [int(result.get("written", 0)), "; ".join(errs.slice(0, 3))]
	_refresh_state()


func _on_snapshot_pull_failed(error: String) -> void:
	_set_busy(false)
	_si_status.text = "Restore failed. %s" % error


# Provider found a newer snapshot from another device. Surface the banner if
# the dialog is open; if not, the next show_dialog() will pick it up via
# _refresh_newer_snapshot_banner().
func _on_newer_snapshot_available(_created_at: String, _device_label: String, _snapshot_id: String) -> void:
	if visible:
		_refresh_newer_snapshot_banner()


# Cached session expired during silent refresh at launch — drop back to the
# signed-out state and let the user re-authenticate.
func _on_session_refresh_failed(error: String) -> void:
	_state = State.SIGNED_OUT
	_set_busy(false)
	_so_status.text = "Your session expired. %s" % error
	_refresh_state()


func _on_newer_banner_restore_pressed() -> void:
	if _sync_provider == null:
		return
	_si_status.text = "Restoring newer snapshot from cloud..."
	_set_busy(true)
	_sync_provider.call("pull_latest_snapshot")


func _on_newer_banner_skip_pressed() -> void:
	if _sync_provider == null:
		return
	_sync_provider.call("acknowledge_newer_snapshot_skipped")
	_si_status.text = "Skipped — we won't prompt again until a yet-newer snapshot appears."
	_refresh_newer_snapshot_banner()
