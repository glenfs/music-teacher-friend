# Clefira Godot Project - Requirements and Current Context

## 1. Project Overview
- Product name: `Clefira` (Godot 4.6). On-disk folder is still `musiced/` for backward continuity.
- Goal: build a music education game with ear training and sight reading mini-games.
- Current primary script: `scripts/interval_birds.gd`.
- Theme direction: polished/pro UI with farm-style visual identity and a chicken guide character.

## 2. Core Modes
The app currently has 3 selectable training modes from Home:
1. Interval Ear Training
2. Chord Ear Training
3. Sight Reader

## 3. Home Screen Requirements
- Show title and polished card-based setup UI.
- Inputs:
  - Number of questions (default: 10).
  - Mode selection buttons: Interval / Chord / Sight Reader.
- Start action:
  - Button text: `Start Training`.
- Interval settings:
  - Scale degree toggles `1..8` (all ON by default).
  - `Include Minor` toggle (OFF by default).
- Chord settings:
  - `Inversions` toggle.
  - Chord group buttons:
    - `Maj/Min`
    - `Aug/Dim`
    - `Sus & 7th`
    - `All` (adaptive progression mode)
  - `Adaptive in All` indicator toggle is disabled/read-only (All mode drives adaptive behavior).
- Sight settings:
  - Clef buttons: Treble / Bass.

## 4. Shared Gameplay Systems
- Stats/HUD shown in game card:
  - Lives
  - Streak
  - XP
  - Score and question progress
- Default lives: 3.
- Buttons in game:
  - `Replay`
  - `Slow Mode`
  - `Restart`
  - `Go Back`
- End-of-session behavior:
  - Completion and game-over center overlay.
  - Session performance summary shown.
- Anti-double-answer guard:
  - No extra answer acceptance after round/game is ended.
- Answer feedback timing:
  - Slower transition between questions (with extra delay in Slow Mode).

## 5. Interval Ear Training Requirements
- Each round plays two notes.
- Player sees exactly 3 answer options:
  - 1 correct + 2 distractors.
- Interval labels displayed as full names, e.g.:
  - Major 2nd, Minor 3rd, Perfect 5th, Tritone, etc.
- Scale-degree filtering controlled by Home toggles.
- Bird/chicken flies to correct answer button.
- Visual answer feedback:
  - Correct button blinks green.
  - Wrong selected button blinks red (if wrong), correct blinks green.

## 6. Chord Ear Training Requirements
- Chord prompt playback per round:
  1. Block chord
  2. Short pause
  3. Broken chord (arpeggiated)
- Training groups:
  - `Maj/Min`: only Major + Minor
  - `Aug/Dim`: only Augmented + Diminished
  - `Sus & 7th`: only Sus2, Sus4, Maj7, Dom7, Min7, Dim7
  - `All`: adaptive progression
- `All` adaptive progression order:
  - Early streak: Maj/Min
  - Mid streak: add Aug/Dim
  - High streak: include all chord families
- Inversion option still supported when enabled.
- Visual answer feedback:
  - Correct button blinks green.
  - Wrong selected button blinks red + correct blinks green.

## 7. Sight Reader Requirements
- Show staff, clef, note head, and mini keyboard.
- Clefs: Treble and Bass.
- Note range includes ledger-note territory:
  - Up to 2 ledger lines above and below staff.
- Ledger lines are drawn dynamically for out-of-staff notes.
- Note head styling:
  - White note head, small size, subtle bounce.
- Response feedback:
  - Correct key blinks green with a `tick` marker above.
  - Wrong key blinks red with an `X` marker above.
  - Correct key also indicated in green on wrong attempts.
- Chicken flies toward the correct key target after response.

## 8. Audio Requirements
- Piano-like sampled note playback used where available.
- Result SFX:
  - Positive sound on correct
  - Fail sound on wrong
- End-of-session voice reactions (funny chicken-style) are enabled.

## 9. Visual/UX Requirements
- Farm background and styled UI are in use.
- Home buttons use consistent warm/yellow material-style visual language.
- Selected state on toggle buttons must be clearly visible with stronger border styling.

## 10. Technical Context
- Engine: Godot v4.6 stable (Windows path used for validation).
- Validation method currently used: headless startup check.
- Current known runtime note from headless run:
  - `ObjectDB instances leaked at exit` warning appears, but script parses and runs.

## 11. Current Scope Snapshot
- The project already contains an integrated multi-mode training loop with lives, scoring, XP, replay, restart, and home navigation.
- Main active development is centralized in `scripts/interval_birds.gd` with a single-scene flow.
