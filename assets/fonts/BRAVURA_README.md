# Bravura SMuFL Music Font

The score engine (`scripts/score_engine/`) renders music notation using glyphs from a SMuFL-compatible music font. The recommended font is **Bravura** — a free, open-source reference SMuFL font from Steinberg, released under the SIL Open Font License.

## Installation

1. Download Bravura from the official repo:
   <https://github.com/steinbergmedia/bravura/raw/master/redist/otf/Bravura.otf>

2. Place the file at:
   `res://assets/fonts/Bravura.otf`

3. Restart the app — the score engine auto-detects the font on first use.

## Without Bravura installed

The engine falls back to standard Unicode music symbols (𝄞, 𝄢, ♯, ♭, etc.) rendered with the system font. This works but looks rough — proper engraving quality requires the SMuFL font.

## Why Bravura

Bravura is the SMuFL reference implementation. All glyph positions, sizes, and proportions match what professional scores look like. The score engine's spacing and layout algorithms assume Bravura's glyph metrics; substituting a different SMuFL font (Leland, Petaluma, etc.) will work but may need offset tweaks.

## License

Bravura is released under the SIL Open Font License v1.1, which permits free commercial use, modification, and redistribution. See <https://github.com/steinbergmedia/bravura/blob/master/redist/LICENSE.txt>.
