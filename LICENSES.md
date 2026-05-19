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

- `assets/fonts/Baloo2-SemiBold.ttf`
  - Source: Google Fonts (Baloo 2)
  - License: SIL Open Font License 1.1

- `assets/fonts/Nunito-Regular.ttf`
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

## Audio

- `assets/audio/piano/piano/*.mp3`
  - Source: `TBD`
  - License: `TBD`

- `assets/audio/piano/sampled/*.ogg` (fallback bank)
  - Source: `TBD`
  - License: `TBD`

- `assets/audio/sfx/*` (UI clicks, correct/wrong, fanfare, etc.)
  - Source: `TBD`
  - License: `TBD`

- `assets/audio/sfx/chicken-cluck.wav`
  - Source: Generated programmatically (frequency-sweep chirp)
  - License: Original / In-house

- `assets/audio/sfx/clap.wav`
  - Source: Generated programmatically (filtered noise burst)
  - License: Original / In-house

## Artwork / UI / Backgrounds

- `assets/characters/*`
- `assets/backgrounds/*`
- `assets/icons/*`
- `assets/notation/*`
- `assets/trees/*`
- `assets/farm/*`
  - Source: `TBD`
  - License: `TBD`

## Notes

- Replace each `TBD` with exact source URL/path and final license before release.
- If any asset is custom/original, mark `Source: In-house` and `License: Proprietary`.
