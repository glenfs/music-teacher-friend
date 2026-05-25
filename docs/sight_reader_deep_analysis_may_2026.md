# Sight Reader — Deep Analysis (2026-05-25)

## QA results
- `qa_run.ps1 -Scope sight` → **QA DONE PASS**, no issues recorded
- All sight notes (treble/bass C/wide), sight chord (grand staff), key signatures (C / 2♯ / 2♭) and answer loop steps passed
- Sight Placement coverage: N/A for build
- Sight Continuous / Note Flow coverage: N/A for build (means: not exercised by the QA bot)

The QA bot only proves **mechanical** correctness — pages load, taps register, no crashes. It does not measure UX polish, gamification depth, or pedagogical quality.

## Executive verdict

**Sight Reader is ~65-70% complete and NOT ready to ship as "pro level."**

The core gameplay loops exist (Notes / Chords / Note Flow / Rhythm Flow), but they suffer from:

1. **Missing gamification depth** — streaks and lives exist, but no leaderboards, daily challenges, weekly goals, or "why would I return tomorrow?" hooks
2. **Incomplete UI polish** — result screens are minimal (no celebration, no accuracy %, no mastery progression viz)
3. **Weak answer feedback** — green/red blink only. No "why" explanations during gameplay
4. **Sight Singing is hidden** behind `SIGHT_SINGING_ENABLED = false` — already deferred; needs explicit "v1.1 ship or hide for v1.0" decision
5. **Continuous Flow modes** are skeletal — no per-hit feedback, no accuracy metrics mid-round
6. **No weak-item focus** — stats are tracked but never surfaced

**With ~2-3 weeks of focused work, this could be production-ready (B+).** With another ~2 weeks of follow-up polish, A-grade competitive with Tenuto / Musition.

---

## Per-sub-mode report card

| Sub-mode | Loop | Feedback | Onboard | Difficulty | Win/Lose | Stats | Weak items | Lesson | Polish |
|---|---|---|---|---|---|---|---|---|---|
| **Notes** | ✓ | ⚠ | ✓ | ⚠ | ✓ | ✓ | ✗ | ✓ | ⚠ |
| **Chords** | ✓ | ⚠ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ⚠ |
| **Note Flow** (Continuous) | ⚠ | ✗ | ✗ | ⚠ | ⚠ | ⚠ | ✗ | ✓ | ✗ |
| **Rhythm Flow** | ⚠ | ✗ | ✗ | ⚠ | ⚠ | ✗ | ✗ | ✓ | ✗ |
| **Sight Singing** | n/a — gated `SIGHT_SINGING_ENABLED = false` | | | | | | | | |
| **Note Chase** (separate mode) | ✓ | ✓ | ⚠ | ✓ | ✓ | ⚠ | ✗ | n/a | ✓ |

---

## Top 10 prioritized improvements

### Ship-blockers (must fix for paid release)

**1. Note Flow / Rhythm Flow — per-hit visual feedback** · 4-6 hrs
- Currently silent until round end. Players can't tell if their tap was correct.
- Show green/red flash near each note on tap, running ACC % in HUD, "Perfect / Good / Miss" label per hit.
- Files: `_update_continuous_sight()` (~`interval_birds.gd:32349`), after `_continuous_sight_correct_hits += 1`.

**2. Rhythm Flow — animated onboarding overlay** · 3-4 hrs
- No one knows what "tap the glyphs" means without instruction.
- 3-second overlay: 1-2 glyphs scroll, finger icon taps at the right moment + "Tap rhythm glyphs as they pass the line" + "TAP TO START".
- New function `_show_rhythm_flow_intro_overlay()`.

**3. Sight Singing — decide: complete or hide cleanly** · 1 hr (hide) or 10-15 hrs (complete)
- Currently gated `SIGHT_SINGING_ENABLED = false` with "incomplete" comment.
- **Recommended:** ship hidden in v1.0; complete in v1.1.
- To complete: phrase scoring (contour + pitch deviation), result UI, lesson session integration.

**4. Chords — per-chord-type stats tracking** · 3-4 hrs
- Currently `_sight_stats_*` doesn't differentiate chord quality. Teacher can't see "weak on Maj7 vs Dom7".
- Change stats dict keys from `"Chords"` to `"Chords:Major"`, `"Chords:Dom7"`, etc.
- Files: `_sight_stats_asked` (~line 1506), `_record_question_correct()` (~17120).

### Polish items (push B+ → A)

**5. Sight Notes / Chords — post-answer "Why this is correct" overlay** · 4-5 hrs
- Pedagogical reasoning currently only via hints after 3 taps.
- 2-second overlay after each answer: "✓ Correct! F is the 4th line of treble." Can disable in settings.
- Files: new `_show_sight_answer_reason()` from `_on_player_answer_committed()`.

**6. Continuous modes — surface weak-note recommendations** · 5-6 hrs
- Track which notes were missed in Note Flow (currently only ACC %).
- Result screen: "Focus on: F, G, Bb (4/5 misses)".

**7. All modes — end-of-round celebration screen** · 6-8 hrs *(biggest gamification win)*
- Currently quiz ends silently.
- Animated headline tied to accuracy, accuracy badge (green/yellow/red), mastery progress bar ("F major 65% → 72%"), "Next up: 3 weak items" chip.
- Optional confetti particle.

**8. Sight Notes — adaptive difficulty ramp** · 3-4 hrs
- Track `_question_index / _total_questions` ratio.
- Early (0.0-0.3): staff lines/spaces (C–G treble). Mid (0.3-0.7): add ledger. Late (0.7-1.0): add accidentals.
- Mirror the interval mode pattern at line ~20957.

**9. Grand Staff — voicing explanation tooltip** · 2-3 hrs
- Help teachers understand why certain chord voicings are shown.
- Small label: "Root: C, Bass: G, Voicing: 2nd Inversion".

**10. Lesson session — weak items summary in activity record** · 2-3 hrs
- Add `"weak_items": ["F", "G"]` to lesson activity dict.
- Dashboard "Needs Work" card surfaces these by mode + key.

---

## Gamification opportunities (3-5 hrs each)

These are NEW SYSTEMS, not polish — would meaningfully raise stickiness.

| Idea | Effort | Impact |
|---|---|---|
| **Daily Challenge** ("Today: 10 Chords, F major, beat your high score") | 4 hrs | high |
| **Mastery Badges** ("F Major Master", "Chord Whiz", "Rhythm Ace") | 4-5 hrs | medium |
| **Weekly Practice Goals** ("50 correct Sight Notes by Friday") | 3-4 hrs | high |
| **Streak Leaderboard** (Teacher Edition, top streaks across students) | 2 hrs | medium |
| **Per-key accuracy radar** (home card + dashboard) | 3-4 hrs | high |

---

## Quick wins (< 2 hrs each)

1. "Perfect!" toast when accuracy = 100% (0.5 hr)
2. Running accuracy % shown mid-round in Continuous modes (1 hr)
3. "Hint Used" chip in HUD when count > 0 (0.5 hr)
4. Grand Staff voicing: snap to nearest staff-line to reduce ledger (1.5 hr)
5. Result screen: "Next 3 focus items" chip using existing `compute_missed_ids()` (1 hr)
6. Test + fix Sight setup on 500 px width (1 hr)

---

## Music-education quality assessment

**Notes / Chords mode:** ✓ Pedagogically sound. Tiered progression matches textbook order; grand staff voicing is realistic with good voice-leading.

**Note Flow / Rhythm Flow:** ⚠ Skeletal pedagogy. Missing scaffolding — no "slow-mode-first then speed up" option for beginners.

**vs competitors:**

| Feature | Tenuto | Teoria | Musition | Yousician | **Clefira** |
|---|---|---|---|---|---|
| Daily challenges | ✓ | – | – | ✓ | ✗ |
| Mastery badges | – | – | – | ✓ | ✗ |
| Progress analytics | ✓ | – | ✓ | ✓ | ⚠ |
| Realistic piano voicing | ✓ | – | – | – | ✓ |
| Teacher dashboard | (Studio only) | – | – | – | ✓ |
| Per-hit feedback | ✓ | – | – | ✓ | ⚠ |
| Theory integration | – | ✓ | ✓ | – | ⚠ |
| Visual identity | – | – | – | – | ✓ (farm/chicken) |

Clefira's wins: realistic grand staff voicing, teacher dashboard, distinctive visual identity.
Clefira's losses: gamification depth, polish on result screens, per-hit feedback in scroll modes.

---

## Path to ship-ready

### **Minimum viable v1.0 (2-3 weeks)**
- Hide Sight Singing button cleanly (1 hr) — already done via `SIGHT_SINGING_ENABLED`
- Per-hit feedback in Note Flow / Rhythm Flow (5-6 hrs)
- Rhythm Flow onboarding overlay (3-4 hrs)
- Chord per-quality stats (3-4 hrs)
- Post-answer "why" overlay (4-5 hrs)
- Celebration screen for all modes (6-8 hrs)

**Verdict after these:** B+ — professional, educationally sound. Not Tenuto-level but credibly paid.

### **Polish v1.1-1.2 (follow-up)**
- Weak-item focus recommendations
- Daily challenges
- Mastery badges
- Sight Singing completion
- Teacher dashboard sight analytics

**Final verdict:** A — competitive with Tenuto / Musition.

---

## Key files & line numbers (for the dev pickup later)

| Component | File | Lines |
|---|---|---|
| Sight options UI build | `interval_birds.gd` | 4610-5000 |
| Notes question gen | `interval_birds.gd` | 21130-21143 |
| Chords question gen | `interval_birds.gd` | 33551-33681 |
| Continuous update loop | `interval_birds.gd` | 32349-32600 |
| Grand staff layout | `score_engine/staff_renderer.gd` | 1247-1454 |
| Chord voicing | `music_theory/chord_voicing_generator.gd` | 1-400 |
| Stats tracking | `interval_birds.gd` | 1506-1507 (`_sight_stats_*`) |
| Lesson session | `students/lesson_session.gd` | 90-130 |
| Responsive layout | `interval_birds.gd` | 2976-3004 |
| Sight Singing gate | `interval_birds.gd` | 128 (`SIGHT_SINGING_ENABLED`) |
