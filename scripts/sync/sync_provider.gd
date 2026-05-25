extends Node
class_name SyncProvider

# Abstract base class for cloud-sync backends.
#
# Tier A scope: backup/restore via a single snapshot row per user. The interface
# is intentionally narrow so Tier B (per-record sync) can swap in a different
# impl behind the same call sites without touching the dashboard UI.
#
# All methods are async — they return immediately; callers listen for the paired
# signal to know when the operation finished.

# --- Auth signals ---
signal magic_link_sent(email: String)
signal magic_link_failed(error: String)
signal signed_in(user_id: String, email: String)
signal sign_in_failed(error: String)
signal signed_out()

# --- Snapshot signals ---
signal snapshot_pushed(snapshot_id: String, created_at: String)
signal snapshot_push_failed(error: String)
signal snapshot_pulled(bundle: Dictionary, created_at: String, device_label: String)
signal snapshot_pull_failed(error: String)

# Fires after check_for_newer_snapshot() if the server has a snapshot newer
# than this device has seen — used to drive the "newer snapshot from another
# device — restore it?" banner on launch.
signal newer_snapshot_available(created_at: String, device_label: String, snapshot_id: String)

# --- Generic ---
signal session_restored(user_id: String, email: String)
# Fires when a cached session failed silent refresh at launch (refresh token
# expired or revoked). UI should treat this as "user is now signed out".
signal session_refresh_failed(error: String)


# --- Public API (implementations override these) ---

# Sends a one-time code to the email. Emits magic_link_sent / magic_link_failed.
func send_magic_link(_email: String) -> void:
	push_error("SyncProvider.send_magic_link not implemented")


# Exchanges (email + 6-digit code) for a session. Emits signed_in / sign_in_failed.
func verify_otp(_email: String, _token: String) -> void:
	push_error("SyncProvider.verify_otp not implemented")


# Drops the local session and (best-effort) revokes the refresh token. Emits signed_out.
func sign_out() -> void:
	push_error("SyncProvider.sign_out not implemented")


# Pushes a snapshot bundle to the server. Emits snapshot_pushed / snapshot_push_failed.
func push_snapshot(_bundle: Dictionary, _device_label: String) -> void:
	push_error("SyncProvider.push_snapshot not implemented")


# Pulls the most recent snapshot for the signed-in user. Emits snapshot_pulled / snapshot_pull_failed.
func pull_latest_snapshot() -> void:
	push_error("SyncProvider.pull_latest_snapshot not implemented")


# Lightweight check: peeks at the latest cloud snapshot's metadata and emits
# newer_snapshot_available if the server has something newer than this device
# has seen. Does NOT apply the snapshot. Used for pull-on-launch.
func check_for_newer_snapshot() -> void:
	push_error("SyncProvider.check_for_newer_snapshot not implemented")


# Records the pending newer-snapshot as "user has seen this and chose not to
# restore" so we don't prompt again until a yet-newer one appears.
func acknowledge_newer_snapshot_skipped() -> void:
	push_error("SyncProvider.acknowledge_newer_snapshot_skipped not implemented")


# Returns true when check_for_newer_snapshot found something the user hasn't acknowledged.
func has_pending_newer_snapshot() -> bool:
	return false


# Returns { created_at, device_label, snapshot_id } for the pending newer snapshot, or {} if none.
func pending_newer_snapshot_info() -> Dictionary:
	return {}


# Most recent successful push / pull timestamps (ISO 8601). Empty when never synced.
func last_pushed_at() -> String:
	return ""


func last_pulled_at() -> String:
	return ""


# Returns true when the provider has a usable session (signed-in or refreshable).
func is_signed_in() -> bool:
	return false


func current_user_id() -> String:
	return ""


func current_user_email() -> String:
	return ""
