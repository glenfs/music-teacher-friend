# Third-Party Asset Licenses

This file tracks source and license for external assets used in Clefira.

Status: complete — every asset has a recorded source + license. Last reviewed 2026-06-08.

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

- `assets/fonts/DejaVuSans.ttf` (Unicode symbol glyph fallback for the Web build)
  - Source: DejaVu Fonts project — https://dejavu-fonts.github.io
  - License: Bitstream Vera Fonts License + DejaVu changes (public-domain-friendly,
    permissive; redistribution allowed). https://dejavu-fonts.github.io/License.html
  - Notes: Used only on the Web export as a glyph fallback (arrows, geometric
    shapes, gear, checks, accidentals) since the browser sandbox has no OS fonts
    for Godot's TextServer to fall back to. Bundled font, no attribution required
    in-app but credited here.
  - Notes: Hand-drawn / jazz lead-sheet style. Casual look ideal for jazz and
    lead-sheet exercises. Free for any use including commercial.

## Audio — Piano samples

- `assets/audio/piano/piano/1.mp3` … `88.mp3` (numbered 88-key sample bank, 1 = A0 / MIDI 21, 88 = C8 / MIDI 108)
  - Source: Salamander Grand Piano V3 by Alexander Holm
  - Project page: https://archive.org/details/SalamanderGrandPianoV3 (Archive.org mirror)
  - Original author site: https://sfzinstruments.github.io/pianos/salamander
  - Instrument: Yamaha C5 Concert Grand
  - License: Creative Commons Attribution 3.0 (CC-BY 3.0) — https://creativecommons.org/licenses/by/3.0/
  - Attribution requirement (must appear in app + store page): "Salamander Grand Piano by Alexander Holm, licensed under CC-BY 3.0"
  - Notes: Industry-standard free piano library used by Linux MuseScore, Carla, and many indie music apps. Project ships one selected velocity layer per note (downloaded + converted via `scripts/tools/fetch_salamander.ps1`). The full library is 16 velocity layers per note (~700 MB compressed); subset shipped is ~30-80 MB compressed.
  - Modifications: Salamander V3 samples every minor third (A/C/D#/F# per octave) rather than every chromatic note. To produce a full 88-key set, samples were (1) filtered to a single velocity layer (v9 - mezzo-forte), (2) pitch-shifted by +/-1 semitone via ffmpeg's asetrate filter to cover chromatic notes between sampled pitches, (3) re-encoded to 160 kbps MP3 to match the project's existing numbered-file loader convention. The CC-BY 3.0 license permits these modifications provided attribution is retained.

- `assets/audio/piano/sampled/*.ogg` (fallback / sampled bank, octave overrides) — DEPRECATED
  - Status: superseded by Salamander Grand Piano. Remove this directory before ship if no longer referenced.

## Audio — SFX (freesound.org CC0 + in-house generated)

Files whose filenames follow the `<id>__<user>__<name>` freesound.org convention:

- `assets/audio/sfx/178668__hanbaal__snare.wav`
  - Source: "snare.wav" by Hanbaal — https://freesound.org/s/178668/
  - License: CC0 (public domain — no attribution required).

- `assets/audio/sfx/268185__andychristen__wristwatchtic-tac.wav`
  - Source: "Wristwatch.Tic-Tac.wav" by andychristen — https://freesound.org/s/268185/
  - License: **CC BY 4.0** — attribution required. Credit: "Wristwatch.Tic-Tac.wav"
    by andychristen (freesound.org), licensed under CC BY 4.0.

- `assets/audio/sfx/50982__matiasreccius__bass2.wav`
  - Source: "bass2.wav" by Matias.Reccius — https://freesound.org/s/50982/
  - License: CC0 (public domain — no attribution required).

In-house (generated):

- `assets/audio/sfx/chicken-cluck.wav` — generated programmatically (frequency-sweep chirp). License: Original / In-house.
- `assets/audio/sfx/clap.wav` — generated programmatically (filtered noise burst). License: Original / In-house.

Sourced from [freesound.org](https://freesound.org). All are **Creative Commons 0** (public domain — no attribution legally required; credited here as courtesy and for provenance):

- `assets/audio/sfx/correct.mp3` — "RightAnswer.mp3" by Gronkjaer — https://freesound.org/s/554055/ — License: CC0
- `assets/audio/sfx/fail.mp3` — "WrongAnswer.mp3" by Gronkjaer — https://freesound.org/s/554053/ — License: CC0
- `assets/audio/sfx/module-complete.wav` — "Game Menu Achievement" by CogFireStudios — https://freesound.org/s/619833/ — License: CC0
- `assets/audio/sfx/new_question.wav` — "ui-submit.wav" by StavSounds — https://freesound.org/s/701704/ — License: CC0
- `assets/audio/sfx/powerup.wav` — "PowerUp.wav" by kianda — https://freesound.org/s/328120/ — License: CC0
- `assets/audio/sfx/transition-whoosh-sound.wav` — "Transition whoosh sound.wav" by SKsemi — https://freesound.org/s/432922/ — License: CC0
- `assets/audio/sfx/fanfare-2-rpg.wav` — "Fanfare 2 - Rpg" by colorsCrimsonTears — https://freesound.org/s/580310/ — License: CC0
- `assets/audio/sfx/ui-basic-click.wav` — "UI Series: Another basic click" by brandondelehoy — https://freesound.org/s/333429/ — License: CC0
- `assets/audio/sfx/ui__snap-click-01.wav` — "Snap Click 01.wav" by ironcross32 — https://freesound.org/s/582898/ — License: CC0

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
  - Source: Lucide — https://lucide.dev
  - License: ISC — https://github.com/lucide-icons/lucide/blob/main/LICENSE. Free
    for commercial use. Include LICENSE in distribution if redistributing source.

- `assets/icons/bullseye.svg`
  - Source: Original artwork drawn for Clefira (concentric-ring bullseye in the
    Clefira navy/gold palette). License: Original / In-house — owned by the
    Clefira project. No third-party attribution required.

- `assets/icons/memorize.svg`, `vanish.svg`, `recall.svg`, `correct.svg`,
  `wrong.svg`, `interval-up.svg`, `interval-down.svg`, `progress.svg`
  - Source: Original artwork drawn for Clefira (Note Recall + Interval Reading
    UI icon set, in the Clefira navy/gold/teal/coral palette). Replaces font
    emoji in those modes. License: Original / In-house — owned by the Clefira
    project. No third-party attribution required.

## Branding (Clefira identity)

- `assets/branding/clefira-*.png` (all sizes: 144/180/192/432/1024 + adaptive variants)
  - Source: AI-generated for Clefira (AI tool + prompt).
  - License: Used under the generating tool's commercial-use terms. Owned/used by
    the Clefira project; no third-party attribution required. (Record the specific
    AI tool + prompt for the project's own provenance file.)

- `assets/logos/*`
  - Source: AI-generated for Clefira (AI tool + prompt).
  - License: Used under the generating tool's commercial-use terms. Owned/used by
    the Clefira project; no third-party attribution required. (Record the specific
    AI tool + prompt for the project's own provenance file.)

## Birds / Spritesheets (gameplay characters)

- `assets/birds/chicken.png`, `chicken.svg`, `idle.png`
- `assets/birds/spritesheet/*.png` (happy / hop / sad / front jump / peack eat)
  - Source: Commissioned artwork (Fiverr) — created for Clefira as work-for-hire.
  - License: Proprietary — full commercial usage rights acquired from the artist
    via the Fiverr commission. Owned by the Clefira project; no third-party
    attribution required. Keep the Fiverr order/receipt on file as the
    rights-transfer reference.

## Backgrounds

- `assets/backgrounds/blue_gradient.png`, `classroom.png`, `clefire.png`, `farm_scene.png` … `farm_scene_5.png`, `windmill_town.png`
  - Source: AI-generated for Clefira.
  - License: Used under the generating tool's commercial-use terms. Owned/used by
    the Clefira project; no third-party attribution required. (Record the specific
    AI tool + prompt for the project's own provenance file.)

## Farm / Trees / UI props

- `assets/farm/*`, `assets/trees/*`, `assets/ui/*`
  - Source: AI-generated for Clefira (AI tool + prompt).
  - License: Used under the generating tool's commercial-use terms. Owned/used by
    the Clefira project; no third-party attribution required. (Record the specific
    AI tool + prompt for the project's own provenance file.)

## Notes

- The only attribution-required asset in use is the CC BY 4.0 wristwatch tic-tac
  sound (above); its credit is carried in this file and surfaced in-app via
  Settings → Credits (which opens this bundled LICENSES.md).
- When adding new assets: record exact source URL/path + license here. Mark
  custom/original work `Source: In-house` / `License: Proprietary`. For
  AI-generated assets, also record the tool + prompt in the project's provenance
  notes and confirm the tool's commercial-use terms at generation time.
