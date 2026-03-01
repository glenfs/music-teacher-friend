# RhythmGlyph V2 Notes

`RhythmGlyph.tscn` is the Rhythm Flow visual prefab. It is currently vector-drawn in `scripts/rhythm/rhythm_glyph.gd` (no external glyph asset dependency).

## Supported mappings
- `hit + 4.0` -> whole note
- `hit + 2.0` -> half note
- `hit + 1.0` -> quarter note
- `rest + 4.0` -> whole rest
- `rest + 2.0` -> half rest
- `rest + 1.0` -> quarter rest

Other durations (e.g. `0.5`, `1.5`) fall back to a neutral duration block so gameplay remains stable.

## Adding new durations later
1. Update `_map_glyph_kind()` in `scripts/rhythm/rhythm_glyph.gd`.
2. Add a new `_draw_*()` method for the glyph.
3. Keep `place_on_staff()` anchor alignment unchanged so timing visuals still line up with the hit line.

