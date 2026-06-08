# Clefira Student Edition — Production Readiness (Google Play)

Last updated: 2026-06-08 · Target: `com.clefira.student` v1.0.0 (versionCode 1)

This is the single source of truth for shipping the **Student Edition** to Google Play.
It tracks every checklist item from `docs/prompts/production ready.txt` plus the
work done in-repo. Legend: ✅ done in repo · 🟡 needs a one-time fact/decision ·
🔵 must be done in Play Console / on your account (cannot be automated here).

---

## 1. Build artifact — AAB, not APK ✅

Google Play requires an **Android App Bundle (.aab)** for new apps, not a sideloaded APK.

- New export preset **"Android - Student AAB"** (`export_presets.cfg`, `preset.6`):
  - `gradle_build/export_format=1` → AAB
  - `gradle_build/target_sdk="35"` (Android 15 — meets the current Play target-SDK rule)
  - `architectures/arm64-v8a=true` only (64-bit, Play-compliant)
  - `permissions/internet=false` — Student Edition makes **no network calls** (no cloud, no billing, no analytics). Dropping the permission makes the "nothing leaves your device" claim verifiable by Play's reviewers.
  - `permissions/record_audio=true` — kept; needed for the optional mic pitch-detection exercises.
  - `package/app_category=1` (audio) — accurate for a music app.
- Build command:
  ```powershell
  .\tools\build_student_releases.ps1 -Target Android -Aab
  ```
  Output: `builds/android/student/ClefiraStudent.aab` (signed release).
- The plain `-AndroidRelease` / default paths still produce sideloadable APKs for device testing.

## 2. Target SDK ✅ (verify in Console)

- Preset pins `target_sdk=35`. Device logs from a prior install confirmed `target_sdk_version=35`.
- 🔵 Play Console will re-verify on upload. Current rule: API 35 (Android 15) for new apps. No action expected.

## 3. Signing + Play App Signing 🟡 / 🔵

- Release/upload keystore lives at `keys/clefira-upload.jks` (gitignored — keep it + its password backed up safely). Create it with:
  ```powershell
  & "C:\Program Files\Java\jdk-17.0.4.1\bin\keytool.exe" -genkeypair -v -keystore "keys\clefira-upload.jks" -alias clefira-upload -keyalg RSA -keysize 2048 -validity 10000
  ```
  The AAB preset has `package/signed=true`.
- The build script now auto-sets the keystore **path** to `keys/clefira-upload.jks` and reads the secret **alias + password** from env vars (so secrets stay out of git). Run:
  ```powershell
  $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER     = '<your-key-alias>'
  $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = '<your-keystore-password>'
  .\tools\build_student_releases.ps1 -Target Android -Aab
  ```
- 🟡 You must supply the alias + password once per shell (or configure them permanently in Godot **Editor Settings → Export → Android**). Without them the build stops with a clear message.
- 🔵 **Play App Signing**: on first upload Google generates/holds the *app signing key*; your `clefira-upload.jks` becomes the *upload key*. Keep it (and its passwords) backed up — losing the upload key requires a Google reset.

## 4. Privacy policy ✅ + Data Safety form 🔵

The Student Edition is **fully local**: Cloud Sync lives only in the Teacher Dashboard (Teacher-Edition-only), so the Student build has no sign-in, no cloud, no analytics, and no internet permission. Mic audio is processed on-device for pitch detection and never recorded or transmitted.

- ✅ `docs/PRIVACY.html` updated: placeholders resolved (`contact@clefira.app`, provider = Supabase), added a Student-Edition clarification box, dated 2026-06-08. The public copy at `website/privacy.html` already uses `contact@clefira.app`.
- ✅ Privacy policy is live at **https://clefira.app/privacy** (deployed to Cloudflare Pages, production). Paste this URL into the Play listing.

### Data Safety form — answers for the Student Edition

> These reflect the actual Student build (no network permission). Use verbatim.

| Question | Answer |
|---|---|
| Does your app collect or share any user data? | **No** |
| Data collected | None |
| Data shared with third parties | None |
| Is data encrypted in transit? | N/A (no data leaves the device) |
| Can users request data deletion? | Data is local only; uninstalling removes it |

**Microphone note for the reviewer:** the app requests `RECORD_AUDIO` for real-time
pitch-detection exercises. Audio is analyzed on-device and is never recorded,
stored, or transmitted. This is *not* data collection under the Data Safety policy.

## 5. Store listing 🔵

In Play Console → Main store listing:
- App name: **Clefira** (or "Clefira — Music Learning").
- Short + full description (the website copy can be reused).
- App icon (512×512), feature graphic (1024×500).
- Screenshots: phone (min 2) + 7-inch/10-inch tablet recommended. Capture from a real device or `builds/windows` running at a phone aspect.
- App category: **Education** (or Music & Audio). Content rating: complete the questionnaire (this app → "Everyone").
- Target audience & content: select the age bands you intend (see §7).

## 6. Content rating, target audience 🔵

- Complete the IARC content-rating questionnaire — expected **Everyone / PEGI 3**.
- Target audience: if you mark ages under 13, Play applies the **Families** policy (extra requirements). Marking 13+ avoids Families-program obligations. Decide deliberately (see open question below).

## 7. Closed testing requirement (new personal accounts) 🔵

If this is a **new personal developer account**, Play requires **closed testing with ≥12 testers opted-in for 14 continuous days** before you can request production access.
- Create a Closed testing track, upload the AAB, recruit ≥12 testers (real Google accounts), keep them opted-in 14 days, then apply for production.
- Start this early — it's the longest pole to launch.

---

## Remaining in-repo blockers

- ✅ **Asset licensing (`LICENSES.md`)**: all 9 previously-`TBD` SFX traced to freesound.org via `attribution.txt` — every one is **CC0** (public domain, no attribution required), now credited in `LICENSES.md`. Confirmed `fail.mp3` is in use (game-over jingle). `success.mp3` was unused and removed.
- ✅ **EULA** (`docs/EULA.html`): all placeholders resolved — Licensor = **Glenford Soans**, governing law = **Karnataka, India**, contact = `contact@clefira.app`. (Swap in a company name later if you register one.)

## Open questions for you

1. **Pricing / target age band** — free (and which age bands)? This drives whether the Families program applies (§6/§7).
2. **Support email** — `contact@clefira.app` (via Cloudflare Email Routing → forwards to Gmail). Used across the app docs, EULA, and website. Confirm the routing rule is enabled in Cloudflare so the inbox actually receives mail.
