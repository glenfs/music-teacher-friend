# Asset Requirements (v1 Launch)

This file lists exactly what assets are needed for the current Godot app.
Use this as the sourcing/design checklist.

## Top Priority (Must Have)

### 1) Main Character (Chicken) - Game Ready
- Purpose: Core game feedback and personality across training modes.
- Required animations/states:
  - `idle`
  - `walk`
  - `hop`
  - `peck_eat` (for reward)
  - `celebrate` (for correct/completion)
  - `sad` (for wrong/game over)
- Format:
  - PNG sprite sheets with transparent background
  - Frame size consistent across all animations
- Resolution:
  - 2x or 4x quality (minimum clear at ~160x160 on screen)
- Naming example:
  - `assets/characters/chicken/idle.png`
  - `assets/characters/chicken/walk.png`

### 2) Piano Note Audio Set (Consistent Instrument)
- Purpose: Ear training and chord playback quality.
- Required range (minimum):
  - Chromatic notes from `A2` to `C6`
- Format:
  - Prefer `.ogg` (or `.wav` if needed)
- Audio quality:
  - Uniform loudness (normalized)
  - Same piano tone family (no mixed instruments)
- Naming example:
  - `assets/audio/piano/C4.ogg`, `assets/audio/piano/F#4.ogg`

### 3) Core UI SFX Pack
- Purpose: Feedback and polish.
- Required sounds:
  - `ui_click`
  - `correct`
  - `wrong`
  - `new_question`
  - `transition_whoosh`
  - `completion_fanfare_short`
- Format:
  - `.ogg` preferred
- Length guidance:
  - Click/feedback: 50-500 ms
  - Fanfare: <= 2 s

### 4) Readable Font Pair (Commercial Safe)
- Purpose: Pro UI quality and readability.
- Required:
  - One display/title font
  - One body/UI font (high readability)
- Must include license proof for app distribution.
- Format:
  - `.ttf`/`.otf`

### 5) Background Set (At Least 2 Scenes)
- Purpose: Visual quality and variation.
- Required scenes:
  - `farm_day`
  - sunset farm
  - `classroom_or_practice_room`
  - stage/performance room
- Format:
  - PNG/JPG
- Resolution:
  - 1920x1080 minimum
- Composition requirement:
  - Keep center play area low-clutter for note/chicken visibility

### 6) Music Notation Symbols (Clean High-Quality)
- Purpose: Sight reading clarity.
- Required symbols:
  - Treble clef
  - Bass clef
  - Sharp, flat, natural
- Format:
  - SVG preferred, PNG fallback
- Requirement:
  - Crisp at small and medium sizes

### 7) Essential UI Icons (Single Style)
- Purpose: Interface consistency.
- Required icons:
  - home, back, replay, start, end, settings, audio on/off, info, close, check, x
- Format:
  - SVG preferred + PNG fallback
- Requirement:
  - One consistent visual style/line weight


## Good To Have (Post-v1 Polish)

### 8) Voice Pack (Chicken Coach)
- Lines:
  - "Wow", "Good", "Hmm", "Try again", "Great job"
- Format:
  - WAV/OGG, clean/noise-free

### 9) UI Theme Kit (9-slice)
- Components:
  - panel cards, buttons, tabs, toggles, inputs, progress bars
- Benefit:
  - faster professional skinning and consistency

### 10) Reward Visual Pack
- Items:
  - badges, medals, stars, confetti sprites
- Benefit:
  - stronger motivation loop

### 11) Transition/Loading Animations
- Items:
  - short scene transition strips/sprites
- Benefit:
  - premium feel between modules

### 12) Expanded Background Variants
- Additional scenes:
  - sunset farm, indoor lesson room, stage/performance room
- Benefit:
  - reduced visual fatigue

### 13) Branding Kit
- Items:
  - app icon (all platform sizes), splash, logo lockups, color tokens
- Benefit:
  - store-ready polish


## Delivery Specs (Important)

- Keep source files organized by folder:
  - `assets/characters/`
  - `assets/audio/piano/`
  - `assets/audio/sfx/`
  - `assets/backgrounds/`
  - `assets/icons/`
  - `assets/fonts/`
  - `assets/notation/`
- Use lowercase file names, no spaces.
- Keep a simple `LICENSES.md` noting source + license for every external asset.
- Prefer consistent style over quantity.


## Minimum v1 Asset Bundle (If Time Is Tight)

If only sourcing a small set now, prioritize in this order:
1. Chicken animation set (basic states)
2. Full piano notes (A2-C6)
3. Correct/wrong/new-question/click SFX
4. Font pair
5. 2 clean backgrounds
6. Treble/Bass + accidental symbols
7. Essential icons
