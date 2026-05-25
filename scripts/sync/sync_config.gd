extends RefCounted
class_name SyncConfig

# Supabase project endpoint + publishable client key for Cloud Sync (Tier A).
#
# The publishable key (sb_publishable_*) is INTENDED to be embedded in client
# apps. It grants NO special privileges by itself — every request still goes
# through Row Level Security (RLS) policies on the database, which enforce
# "users can only read/write their own rows" server-side. Rotate from the
# Supabase dashboard if needed; no code change beyond the constant below.
const SUPABASE_URL := "https://lvzivrpkmybwadylaxye.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_d_yz_S0I6sNXTHJsX5vj7Q_7eckGMkK"

# Auth + REST endpoint paths (PostgREST + GoTrue conventions).
const AUTH_OTP_PATH := "/auth/v1/otp"
const AUTH_VERIFY_PATH := "/auth/v1/verify"
const AUTH_REFRESH_PATH := "/auth/v1/token?grant_type=refresh_token"
const AUTH_LOGOUT_PATH := "/auth/v1/logout"
const AUTH_USER_PATH := "/auth/v1/user"
const REST_SNAPSHOTS_PATH := "/rest/v1/sync_snapshots"

# Where the cached session (access + refresh token) lives on disk between runs.
# Lives in user:// so it's per-machine and not checked into the project.
const SESSION_PATH := "user://sync_session.json"

# Local-data locations the snapshot bundle reads from / writes to.
const STUDENTS_ROOT := "user://students"
const TEACHER_DATA_PATH := "user://teacher_data.json"
const EAR_SETTINGS_PATH := "user://ear_settings.json"
const PROGRESS_DATA_PATH := "user://progress_data.json"
const LEARNING_PROGRESS_PATH := "user://learning_progress.json"

# Network behavior.
const HTTP_TIMEOUT_SECONDS := 30.0
# Token is refreshed when its remaining lifetime drops below this.
const ACCESS_TOKEN_REFRESH_MARGIN_SECONDS := 60
