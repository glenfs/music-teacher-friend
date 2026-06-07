# Release Plan — Freemium with 15-min Daily Cap

**Status:** planning. Authoritative once approved.
**Last updated:** 2026-05-30.
**Supersedes:** parts of `docs/release_sku_strategy.md` (see Open Decisions §1).

---

## TL;DR

Ship Clefira as a single free app with a **15-minute-per-day active-practice cap**. Paid upgrade removes the cap (and unlocks Teacher mode). Estimated **~3–4 weeks of focused work** to launch-ready, broken across cap + billing + telemetry + legal/signing.

The cap is the conversion engine. Telemetry is what tells us if it's working. Both must ship together — caps without telemetry is flying blind, telemetry without caps gives us nothing to measure.

---

## Open Decisions (resolve before starting)

These have to be answered first; they change the work plan downstream.

### 1. Single freemium app vs SKU split

`docs/release_sku_strategy.md` currently documents **two SKUs**: Student (free) + Teacher (paid one-time). The 15-min cap plan implies a **single freemium app** instead.

| Model | Pros | Cons |
|---|---|---|
| **Two SKUs** (current docs) | Simple — no in-app billing, no time tracker. Paid teacher upgrade is just "download the paid app." | Hard wall — students who want unlimited can't pay-in-app; teachers who want to try first can't. Two artifacts to maintain + ship. |
| **Single freemium** (this plan) | One artifact. Frictionless upgrade. Casual users stay forever (free funnel). Power users pay. | Requires in-app billing infra. Trial-reset abuse possible. |

**Recommendation: single freemium.** The SKU split assumed teachers self-identify upfront; in practice many "I'm just a parent helping my kid" users *become* teachers, and many teachers want to trial before paying. The freemium funnel captures both.

If the SKU split has external commitments (you've told someone it'll work that way), keep it. Otherwise switch.

### 2. Pricing

| Tier | Price | What unlocks |
|---|---|---|
| **Free** | $0 | All features, 15 min/day active-practice cap |
| **Pro** | $9.99/mo or $69.99 one-time | Unlimited time, Teacher dashboard, multi-student roster, assignments, export |

**Why a one-time option exists:** music education apps historically lean toward one-time purchase (Yousician's $20/mo backlash is instructive). $69.99 one-time is a perpetual-license signal that builds trust with a skeptical teacher audience. The subscription option exists for users who prefer lower upfront commit.

Adjust based on competitive scan — Sight Reading Factory is $34.95/year ($2.91/mo), Tonic Tutor is $7.99/mo. Clefira at $9.99/mo positions as premium but not absurd.

### 3. Billing platform per OS

| Platform | Required billing |
|---|---|
| Android (Google Play) | Google Play Billing — **mandatory** for in-app digital unlocks. 15% rev-cut up to $1M/year, then 30%. |
| Windows (direct download) | Stripe / Paddle / Lemon Squeezy. ~3–5% rev-cut. License key delivered by email. |
| Windows (Steam) | Steam Wallet. 30% rev-cut. Steam handles licensing. |
| iOS (future) | StoreKit. 15–30% rev-cut. |

**Recommendation for v1:** Google Play Billing (Android) + Lemon Squeezy (Windows direct download). Defer Steam. Defer iOS until Android revenue justifies the App Store review pain.

### 4. Telemetry vendor

| Option | Cost | PII/GDPR posture |
|---|---|---|
| **PostHog (cloud)** | Free up to 1M events/mo | Self-serve; good consent + opt-out controls. EU hosting available. |
| **Plausible** | $9/mo for 10k pageviews | Simple, no cookies, GDPR-friendly. Better for web; weaker for app event funnels. |
| **Self-hosted PostHog** | Server cost only | Maximum control; ops overhead. |
| **Firebase Analytics** | Free | Google's terms; SDK is heavy for Godot. Crashlytics is a separate value-add. |
| **Sentry (errors)** | Free tier | Best-in-class crash reporting. Pair with PostHog for events. |

**Recommendation:** PostHog (cloud, free tier) for funnel events + Sentry for crashes. Both have minimal-PII modes; both are GDPR-defensible.

---

## Part A — 15-Minute Daily Cap

### A.1 What counts as "active practice"

**Counts** (the timer ticks while these are happening):
- A drill is mid-session and the user is interacting (Practice Drills, Note Chase, Sight Reader Notes/Rhythm, Interval/Chord/Scale/Progression/Cadence ear training, Sight Singing)
- A learning lesson is in progress
- Free-play Chord Explorer is open AND user has pressed a key in the last 30 seconds

**Doesn't count** (timer paused):
- Sitting on the home menu
- Browsing Settings
- Reading the EULA / Credits
- App is backgrounded (mobile) or minimized (desktop)
- Lesson playback is happening (Conductor is playing audio) but user is idle for >30 sec

The 30-second idle threshold prevents users from "parking" the timer while attempting to cheat the cap.

### A.2 Storage schema

New file: `user://daily_practice_time.json`

```json
{
  "schema_version": 1,
  "by_date": {
    "2026-05-28": { "active_seconds": 612, "sessions": 4, "cap_hit": false },
    "2026-05-29": { "active_seconds": 900, "sessions": 6, "cap_hit": true },
    "2026-05-30": { "active_seconds": 247, "sessions": 2, "cap_hit": false }
  },
  "current_streak_days": 3,
  "longest_streak_days": 14,
  "last_session_iso": "2026-05-30T10:32:18+05:30"
}
```

- Local-date keys (YYYY-MM-DD) using the device timezone.
- `active_seconds` resets at local midnight (new date key created lazily on first session of new day).
- Retain history for 90 days, then prune older entries.

### A.3 Module integration points

A single `DailyPracticeCap` RefCounted module (new: `scripts/product/daily_practice_cap.gd`) exposes:

```gdscript
# Called by every mode at session start. Returns false if cap exceeded.
func can_start_session() -> bool

# Called every ~1 second while a session is active.
func tick(delta_seconds: float) -> void

# Called by every mode at session end (clean exit, game over, abort).
func end_session(reason: String) -> void

# Returns seconds remaining today (0 if cap hit).
func seconds_remaining_today() -> int

# For UI: human-readable "12 min 30 sec left today"
func remaining_text() -> String
```

Wire-up sites (search `interval_birds.gd` for these and inject `can_start_session` / `tick` / `end_session`):
- `_on_start_quiz_pressed` (ear training start)
- Sight Reader session start (`_sight_*_start` family)
- Note Chase start (`_note_chase_*_start`)
- Practice Drills start (`_practice_drills_panel` setup callable)
- Chord Explorer key-press tracker (only count if user actively played within window)
- Lesson Player start
- Splash-to-home transition (don't count)

### A.4 Cap-reached UX

**Soft cutoff philosophy:** never interrupt a drill mid-note. The cap hits at session boundaries, not in the middle of a phrase.

Flow when the user finishes a drill that pushed them over the cap:

1. Result screen displays normally with score / accuracy.
2. Below the standard action buttons (Replay / Next Drill / Home), a new panel appears:
   - **Title:** "You've practiced 15 minutes today — nice work."
   - **Body:** "Come back tomorrow for another free session, or upgrade to Pro for unlimited practice."
   - **Buttons:** `[ Come back tomorrow ]` (returns to home, disables session-start buttons) and `[ Upgrade to Pro ]` (opens billing flow).
3. Home screen shows "Daily practice complete ✓" badge replacing the normal start buttons; all start-session buttons become disabled with tooltip "You've used today's free 15 minutes. Upgrade for unlimited."
4. At local midnight, the badge clears and start buttons re-enable.

**Free preview after cap:** allow the user to *open* any module (see the staff, browse Chord Explorer) but the "Start" button on each is disabled. This keeps the app explorable so they remember it exists.

### A.5 Cap counter HUD

A small chip in the top-right of the home screen + every mode's HUD:

```
[ ⏱ 12:34 / 15:00 free ]    <- mode HUD, while session active
[ ⏱ 12 min left today ]      <- home menu, between sessions
[ ⏱ Daily limit reached ]    <- after cap hit, with Upgrade button beside
```

Pro users see no chip (or optionally a streak / total practice time chip).

### A.6 Edge cases

- **System clock change** — user travels across timezones or fakes their clock. Two safeguards: (1) store the date when each session ENDED in the entry, and reject any new session that would create a date entry more than 24 hours in the past; (2) store a monotonically increasing `last_session_unix` timestamp and refuse to "rewind" the day.
- **App crash mid-session** — `tick()` writes to disk every 30 seconds (not every tick) so a crash loses at most 30 sec of accounting. Acceptable.
- **Multiple devices** — initially each device counts independently. Pro users get unlimited so cross-device sync isn't relevant for them. For free users on multiple devices, the abuse case is "I get 30 min/day by using 2 devices" — acceptable for v1, addressable later via account-based tracking.
- **Reinstall to reset** — local-only tracking can be reset by uninstalling the app. Acceptable for v1; addressable via account-based tracking when accounts ship.

### A.7 Effort estimate

- DailyPracticeCap module + JSON persistence: **1 day**
- Wire-up in all 8 modes: **1 day** (mechanical, but lots of touchpoints in interval_birds.gd)
- HUD chip + home badge: **0.5 day**
- Cap-reached panel + result-screen integration: **0.5 day**
- Edge-case handling (timezone, clock-change, idle-detection): **0.5 day**
- QA test coverage (`qa_run.ps1 -Scope daily_cap` new scope): **0.5 day**

**Subtotal: 4 days.**

---

## Part B — Paid Upgrade Flow

### B.1 What unlocks with Pro

- **Unlimited daily practice** (the cap disappears)
- **Teacher mode** (entire teacher dashboard + roster + assignments + reports)
- **Export to printable PDF / image** (lesson summaries, sight reading sheets)
- **Future-proof:** any feature added later that's clearly a "Pro" feature

What stays free forever:
- All exercise modes themselves (not gated by feature)
- 15 min/day practice
- Personal progress history (last 30 days)
- Daily streak + badges

The line: **Pro removes friction; Free is the full product at one session per day.**

### B.2 Pricing UI surfaces

Where the user sees the upgrade prompt:
1. **Cap-reached panel** (most important — this is the conversion moment)
2. **Home menu chip** when cap is reached
3. **Settings → Upgrade to Pro** entry (passive)
4. **Teacher dashboard entry attempt** (showing it as "Pro only — Upgrade")
5. **First-run onboarding final screen** ("You're on the free plan — 15 min/day, upgrade anytime")

Avoid:
- In-drill upgrade prompts (interrupts practice → hurts the product)
- Email upgrade nags (we don't collect emails in v1)
- Splash-screen upgrade prompts (annoys returning users)

### B.3 License storage

New file: `user://pro_license.json`

```json
{
  "schema_version": 1,
  "status": "pro",
  "purchased_at_iso": "2026-06-01T14:22:33Z",
  "platform": "google_play",
  "product_id": "clefira_pro_lifetime",
  "transaction_id": "GPA.1234-5678-9012",
  "last_verified_iso": "2026-06-15T09:11:00Z",
  "expires_at_iso": null
}
```

- `expires_at_iso` is null for lifetime; ISO date for subscriptions.
- Re-verify periodically (every 7 days on app start) for subscriptions; one-time licenses verify once at purchase + on restore.

A `LicenseStore` RefCounted module (new: `scripts/product/license_store.gd`) exposes:

```gdscript
func is_pro() -> bool
func tier() -> String   # "free" | "pro_monthly" | "pro_lifetime"
func days_until_expiry() -> int   # -1 if lifetime / not pro
func record_purchase(receipt: Dictionary) -> bool
func restore_purchases() -> void   # triggers platform restore flow
```

Every cap check goes through `LicenseStore.is_pro()` — Pro = no cap, no questions.

### B.4 Platform billing integration

**Android — Google Play Billing:**
- Use the Godot Android Billing plugin (or roll a minimal one — the v6 Billing API is well-documented).
- Two SKUs in Play Console: `clefira_pro_lifetime` ($69.99, non-consumable) + `clefira_pro_monthly` ($9.99, subscription).
- Server-side receipt verification is **optional** for non-consumable products; client-side is sufficient if you accept some abuse. For v1, client-side OK.

**Windows direct — Lemon Squeezy:**
- Stripe-like checkout; license key delivered by email; user enters key in Settings to unlock.
- Simpler than Stripe (handles VAT/sales-tax compliance for you).
- The "enter your key" step adds friction; mitigate with a deep-link `clefira://activate?key=ABC123` from the order confirmation email.

**Restore purchases:**
- Android: built into Play Billing, single call.
- Windows: re-enter the key from email; key validates against Lemon Squeezy's API.

### B.5 Refund handling

- Android: Google Play handles refunds; the license expires automatically on refund. Hook `BillingClient.queryPurchasesAsync` on every app start to catch this.
- Windows: Lemon Squeezy webhook → our small license-server (or honor system if we skip the server). For v1, manual refund (we revoke the key on request, user goes back to Free tier on next verify).

### B.6 Effort estimate

- LicenseStore module + JSON persistence: **0.5 day**
- Google Play Billing integration (test purchases in sandbox): **2 days**
- Lemon Squeezy integration (checkout + key entry + verify): **1.5 days**
- Pricing UI in cap-reached panel + Settings + Home chip: **1 day**
- Restore-purchases flow (Android + Windows): **0.5 day**
- Receipt-fraud baseline (basic signature check on Android): **0.5 day**

**Subtotal: 6 days.**

---

## Part C — Telemetry

### C.1 Core funnel events

Every event has: anonymous `device_id` (random UUID generated on first run, stored locally), `app_version`, `platform` (`android` / `windows`), `tier` (`free` / `pro`), `timestamp`.

**Acquisition:**
- `install_first_run` — fired exactly once per device on first launch
- `terms_accepted` — user accepted EULA + Privacy
- `onboarding_completed` — finished the 4-screen intro
- `first_drill_started` — user kicked off their first session of any mode
- `first_drill_completed` — first session reached the result screen

**Activation:**
- `daily_active` — fired once per local-day on first session of that day (NOT every session)
- `session_started { mode, params }` — any session of any mode
- `session_completed { mode, accuracy, duration_sec, exited_via }` — clean completion
- `session_abandoned { mode, duration_sec, reason }` — user backed out

**Conversion:**
- `cap_hit { day_streak_at_hit, days_since_first_run }` — fired when user reaches 15 min
- `upgrade_prompt_shown { surface }` — surface = `cap_panel` / `home_chip` / `settings` / `teacher_attempt` / `onboarding`
- `upgrade_clicked { surface, product_id }`
- `purchase_started { product_id, platform }`
- `purchase_completed { product_id, platform, price_paid_usd }` — converted!
- `purchase_failed { product_id, platform, error_code }`
- `purchase_restored { product_id, platform }`

**Retention:**
- `daily_streak_continued { streak_length }` — fired when daily_active extends streak
- `daily_streak_broken { previous_length, days_gap }` — fired when daily_active after gap
- `uninstall_detected` — fires on next event from a device that hasn't sent in 30+ days (proxy signal)

**Engagement / product:**
- `feature_used { feature_id }` — major features (chord_explorer, smart_drill, mic_test, etc.)
- `mode_session_count_by_day` — aggregated weekly

### C.2 Privacy posture

**Never collect:**
- Email
- Name
- Real device ID (use random UUID generated locally instead)
- Precise location
- IP address (PostHog can be configured to drop this)
- Any audio recordings (mic samples in Sight Singing stay local)
- Student names or teacher names from Teacher mode

**OK to collect:**
- Anonymous device UUID (rotatable; user can reset in Settings → Privacy)
- Country (from IP, then IP dropped)
- App version + platform
- Aggregated practice events (no specific content)
- Crash stack traces (no payload data)

**Consent flow:**
- First-run includes a Privacy screen with the data list above and an Opt-out toggle.
- Setting `analytics_opt_out=true` in settings drops all event sends client-side.
- Opted-out users still get crash reports sent (functional necessity), unless they also toggle `crash_reports_opt_out=true`.

This posture is GDPR-defensible without explicit consent UI complexity, because we don't process PII. Document this in Privacy Policy.

### C.3 Crash reporting (Sentry)

- Drop-in SDK; configure with project DSN.
- Strip user data from contexts before send (no usernames, no paths containing usernames).
- Tag releases with `app_version` so we can attribute crashes to releases.
- On crash: capture stack + last 50 log lines + breadcrumbs (UI state machine transitions).

Already partially implemented per `MEMORY.md` (`user://logs/crash_*.log` writer landed 2026-05-25). Wire that file as a Sentry attachment.

### C.4 Dashboards we need from day 1

Build these in PostHog before launch:

1. **Daily install funnel:** installs → terms_accepted → onboarding_completed → first_drill_completed (drop-offs at each step)
2. **Daily activation:** % of installs that hit `daily_active` on day 1, day 2, day 7, day 30
3. **Cap-hit cohort:** of users who hit the cap at least once, % that ever upgrade
4. **Upgrade funnel:** upgrade_prompt_shown (by surface) → upgrade_clicked → purchase_completed
5. **D7 / D30 retention:** % of new installs still active on day 7 / day 30
6. **Mode popularity:** session_started by mode, weekly
7. **Crash-free rate:** % of sessions that completed without a crash event

### C.5 Effort estimate

- Telemetry client module (`scripts/product/telemetry.gd`): **1 day**
- PostHog SDK integration (manual HTTP POST is fine — no need for a heavy SDK): **0.5 day**
- Sentry integration for crashes: **0.5 day**
- Event instrumentation across all the named events: **2 days**
- Consent UI on first-run + Settings toggles: **0.5 day**
- PostHog dashboards set up: **0.5 day**

**Subtotal: 5 days.**

---

## Part D — Other Pre-Launch Infrastructure

These don't depend on the freemium model but are still launch-blockers.

### D.1 Onboarding (4-screen intro)

- Screen 1: "Welcome to Clefira" + one-line value prop
- Screen 2: "15 minutes of focused practice every day, free forever" (sets cap expectation)
- Screen 3: "Plug in your MIDI keyboard for the full experience" (sets MIDI expectation; "Skip if you don't have one")
- Screen 4: "Pick what you want to practice first" — direct entry into chosen mode

**Effort: 2 days** (UI build + copy + first-run gating).

### D.2 EULA + Privacy Policy finalization

- Replace placeholders in `docs/eula.md` / `docs/privacy_policy.md` (currently TBD per `MEMORY.md` release-prep-may25 notes).
- Either: pay a lawyer ($500–$2000) for review, or use a reputable template (TermsFeed, Iubenda — free tiers exist).
- Privacy Policy must reflect actual data collection from Part C.

**Effort: 1 day (template) + ~2 weeks calendar (lawyer review if going that route).**

### D.3 Code signing

- Windows: EV code signing certificate from Sectigo / DigiCert (~$200–400/year). Critical for avoiding SmartScreen warning.
- Android: already handled by Play Console (Play App Signing).

**Effort: 0.5 day for setup + cert cost + ~3 days calendar (cert issuance).**

### D.4 Asset license audit

- LICENSES.md still has many `TBD` / `Verify` / `Confirm` entries (SFX, backgrounds, branding, birds).
- Each unresolved entry is a legal liability.

**Effort: 1–3 days** depending on how many origin paths can be confirmed vs need re-sourcing.

### D.5 Salamander piano samples

- Attribution: **done** (see updated `LICENSES.md`).
- Script: **done** (`scripts/tools/fetch_salamander.ps1`).
- Run the script: **manual step, ~30 min user time** (download + run + verify).

### D.6 Beta-feature audit

- `MEMORY.md` notes Sight Singing is "Beta — real mic test needed".
- Walk every mode; either ship-ready, label as Beta with disclaimer, or hide.

**Effort: 1 day.**

---

## Critical Path

Ordered by dependency. Items in the same row can run in parallel.

```
Week 1
├── [A] Daily-cap module + persistence + module wire-ups
├── [B.1-B.3] LicenseStore module + UI surfaces (no billing yet)
└── [C.1] Telemetry client + event instrumentation

Week 2
├── [B.4 Android] Google Play Billing integration + sandbox tests
├── [B.4 Windows] Lemon Squeezy integration + key entry
├── [C.2-C.4] Sentry + PostHog dashboards
└── [D.1] Onboarding flow

Week 3
├── [D.2] EULA + Privacy finalization (start lawyer review if going that route)
├── [D.4] LICENSES.md TBD cleanup
├── [D.5] Salamander samples installed
├── [D.6] Beta audit + label/hide pass
└── [QA] Full regression on every mode with cap + Pro flags

Week 4
├── [D.3] Code signing cert installed + signed builds
├── Closed beta with 5–10 users (private invite)
├── Telemetry validation (events actually flowing, dashboards populated)
└── Store listings finalized (descriptions, screenshots, attribution)

Ship.
```

**Total: ~3–4 weeks of focused single-developer work, assuming no major surprises.**

---

## Open Questions

Things I don't yet have enough info on to commit:

1. **Does Godot have a maintained Google Play Billing v6 plugin?** Last time I checked the community plugin was on v4. If not maintained, that's an extra 3–5 days to update.
2. **Lemon Squeezy vs Paddle vs Stripe direct** — Lemon Squeezy is the recommendation but Paddle has stronger VAT handling. Check current pricing/terms before committing.
3. **Pricing validation** — $9.99/mo and $69.99 lifetime are educated guesses. Worth a 1-week competitor scan before locking in.
4. **PostHog free tier limits** — 1M events/mo is generous but if you blow past it the next tier is $0.00045 per event. Worth knowing the break-even install volume.
5. **Closed beta recruitment** — where do the 5–10 users come from? Reddit, Facebook piano-teacher groups, existing wishlist (if any)?

---

## Cross-References

- `docs/release_sku_strategy.md` — superseded in part by this plan (see Open Decisions §1)
- `docs/release_process.md` — release mechanics (build, sign, upload)
- `docs/release_smoke_test.md` — checklist run before every release build
- `docs/smartscreen_signing_options.md` — Windows code-signing options
- `docs/things_do_before_live.html` — earlier ship-readiness analysis (this plan implements its priority list)
- `docs/salamander_piano_setup.md` — how to install the Salamander samples
- `LICENSES.md` — third-party asset attributions (Salamander entry now complete; others still need TBD cleanup)
