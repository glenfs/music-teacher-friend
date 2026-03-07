# Project Notes For Agents

## Piano Sample Mapping (Important)
- Primary bank is `assets/audio/piano/piano` with numbered MP3 files: `1.mp3` .. `88.mp3`.
- Mapping rule: `1 => A0 (MIDI 21)`, each next file is +1 semitone, so `40 => C4`.
- Code source of truth: numbered-bank loader constants in `scripts/interval_birds.gd`
  (`PIANO_NUMBERED_DIR`, `PIANO_NUMBERED_BASE_MIDI`, index range 1..88).
- Legacy `assets/audio/piano/sampled/*.ogg` remains fallback-only when numbered MP3 bank is unavailable.
