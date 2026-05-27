# Third-Party Asset Licenses

This file tracks source and license for external assets used in Clefira.

Status: draft. Complete all `TBD` entries before public distribution.

## Fonts

- `assets/fonts/Poppins-Regular.ttf`
- `assets/fonts/Poppins-SemiBold.ttf`
  - Source: Google Fonts (Poppins)
  - License: SIL Open Font License 1.1

- `assets/fonts/Righteous-Regular.ttf`
  - Source: Google Fonts (Righteous)
  - License: SIL Open Font License 1.1

- `assets/fonts/Inter-Light.ttf`, `assets/fonts/Inter-Regular.ttf`, `assets/fonts/Inter-Medium.ttf` (primary UI font)
  - Source: Rasmus Andersson — https://github.com/rsms/inter
  - Copyright: 2016-2023 The Inter Project Authors
  - License: SIL Open Font License 1.1 (full text in `assets/fonts/Inter-LICENSE.txt`)

- `assets/fonts/Baloo2-SemiBold.ttf` (legacy — kept for theme compatibility)
  - Source: Google Fonts (Baloo 2)
  - License: SIL Open Font License 1.1

- `assets/fonts/Nunito-Regular.ttf` (legacy — kept for theme compatibility)
  - Source: Google Fonts (Nunito)
  - License: SIL Open Font License 1.1

- `assets/fonts/Bravura.otf` (SMuFL music notation glyphs — used by score_engine)
  - Source: Steinberg Media Technologies — https://github.com/steinbergmedia/bravura
  - Author: Daniel Spreadbury
  - License: SIL Open Font License 1.1
  - License text: https://github.com/steinbergmedia/bravura/blob/master/redist/LICENSE.txt
  - Notes: Free for any use including commercial. Bravura is the SMuFL reference
    font; it implements the Standard Music Font Layout spec used by major notation
    apps (MuseScore, Dorico, Finale). Substitute fonts below are drop-in compatible
    since they share the same SMuFL codepoints.

- `assets/fonts/Leland.otf` (SMuFL music notation — alternate engraving font)
  - Source: MuseScore Fonts organization — https://github.com/MuseScoreFonts/Leland
  - Author: Martin Keary, Simon Smith, Robert Piéchaud (commissioned by MuseScore)
  - License: SIL Open Font License 1.1
  - Notes: Default music font in MuseScore 4. Cleaner, slightly thinner strokes
    than Bravura; modern engraved appearance. Free for any use including commercial.

- `assets/fonts/Petaluma.otf` (SMuFL music notation — hand-drawn style)
  - Source: Steinberg Media Technologies — https://github.com/steinbergmedia/petaluma
  - Author: Anthony Hughes
  - License: SIL Open Font License 1.1
  - License text: https://github.com/steinbergmedia/petaluma/blob/master/redist/LICENSE.txt
  - Notes: Hand-drawn / jazz lead-sheet style. Casual look ideal for jazz and
    lead-sheet exercises. Free for any use including commercial.

## Audio — Piano samples (BLOCKER — fill before ship)

- `assets/audio/piano/piano/1.mp3` … `88.mp3` (numbered 88-key sample bank, 1 = A0)
  - Source: `TBD — supply origin (Pianobook? UI Sounds? Salamander? own recording?)`
  - License: `TBD`

- `assets/audio/piano/sampled/*.ogg` (fallback / sampled bank, octave overrides)
  - Source: `TBD`
  - License: `TBD`

## Audio — SFX (mixed: freesound.org + own + TBD)

Files whose filenames follow the `<id>__<user>__<name>` freesound.org convention:

- `assets/audio/sfx/178668__hanbaal__snare.wav`
  - Source: freesound.org, sound id 178668 by user `hanbaal` — https://freesound.org/s/178668/
  - License: `Verify` — freesound page lists CC0 / CC-BY / CC-Sampling+. Confirm and copy exact license + attribution requirement.

- `assets/audio/sfx/268185__andychristen__wristwatchtic-tac.wav`
  - Source: freesound.org, sound id 268185 by user `andychristen` — https://freesound.org/s/268185/
  - License: `Verify` — confirm CC variant and attribution.

- `assets/audio/sfx/50982__matiasreccius__bass2.wav`
  - Source: freesound.org, sound id 50982 by user `matiasreccius` — https://freesound.org/s/50982/
  - License: `Verify` — confirm CC variant and attribution.

In-house (generated):

- `assets/audio/sfx/chicken-cluck.wav` — generated programmatically (frequency-sweep chirp). License: Original / In-house.
- `assets/audio/sfx/clap.wav` — generated programmatically (filtered noise burst). License: Original / In-house.

Origin not yet identified — likely free packs or AI tools:

- `assets/audio/sfx/correct.mp3` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/fail.mp3` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/success.mp3` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/module-complete.wav` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/new_question.wav` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/powerup.wav` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/transition-whoosh-sound.wav` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/fanfare-2-rpg.wav` — Source: `TBD`, License: `TBD` (RPG suffix suggests an RPG SFX pack — name pack + license)
- `assets/audio/sfx/ui-basic-click.wav` — Source: `TBD`, License: `TBD`
- `assets/audio/sfx/ui__snap-click-01.wav` — Source: `TBD`, License: `TBD`

## Icons

- `assets/icons/heroicons/*`
  - Source: Heroicons by Tailwind Labs — https://heroicons.com
  - License: MIT — https://github.com/tailwindlabs/heroicons/blob/master/LICENSE
  - Attribution: not required by MIT; include LICENSE in distribution if redistributing source.

- `assets/icons/lucide/*`
  - Source: Lucide — https://lucide.dev
  - License: ISC — https://github.com/lucide-icons/lucide/blob/main/LICENSE
  - Notes: Free for commercial use. Include LICENSE in distribution if redistributing source.

- `assets/icons/dumbbell.svg`, `ear.svg`, `flame.svg`, `graduation-cap.svg`, `piano.svg`, `scroll-text.svg`
  - These filenames also exist in Lucide. `Verify` whether copied from Lucide (ISC) or hand-drawn — and mark accordingly.

## Branding (Clefira identity — likely in-house or commissioned)

- `assets/branding/clefira-*.png` (all sizes: 144/180/192/432/1024 + adaptive variants)
  - Source: `Confirm` — likely in-house / commissioned for Clefira.
  - License: `Confirm — Original / Proprietary` if so. If commissioned from a designer, capture rights-transfer agreement reference.

- `assets/logos/*`
  - Source: `Confirm — likely in-house / commissioned`
  - License: `Confirm`

## Birds / Spritesheets (gameplay characters)

- `assets/birds/chicken.png`, `chicken.svg`, `idle.png`
- `assets/birds/spritesheet/*.png` (happy / hop / sad / front jump / peack eat)
  - Source: `Confirm` — likely commissioned art or AI-generated.
  - License: `Confirm` — capture artist name + license OR document AI tool + prompt used.

## Backgrounds

- `assets/backgrounds/blue_gradient.png`, `classroom.png`, `clefire.png`, `farm_scene.png` … `farm_scene_5.png`, `windmill_town.png`
  - Source: `TBD` — confirm if AI-generated (capture tool + prompt) or stock (capture URL + license) or in-house.
  - License: `TBD`

## Farm / Trees / UI props

- `assets/farm/*`, `assets/trees/*`, `assets/ui/*`
  - Source: `TBD`
  - License: `TBD`

## Notes

- Replace each `TBD` with exact source URL/path and final license before release.
- For each `Verify` / `Confirm` entry, the filename or naming pattern suggests the answer but it has not yet been independently confirmed.
- If any asset is custom/original, mark `Source: In-house` and `License: Proprietary`.
- For AI-generated assets, capture the tool (Midjourney / DALL-E / SD) and prompt; check the tool's commercial-use terms at the time of generation.
- For freesound.org assets, every sound has its own CC variant — CC0, CC-BY 3.0, CC-BY 4.0, or CC Sampling+. Each must be checked individually; CC-BY requires attribution in the app or store page.
