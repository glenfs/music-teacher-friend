Music Teacher friend

## Rhythm Flow (Sight Reading)

How to start:
- Open `Sight Reading`
- Select `Rhythm Flow`
- Set `Rhythm Flow BPM` (default `80`)
- Start the session, then tap the staff or `Tap` button to begin the 1-bar count-in
- Tap on the beat as rhythm blocks cross the timing line
- Keyboard input also works: `Space` / `Enter` (`tap` action is created at runtime if missing)

How to add new rhythm patterns:
- Edit `scripts/interval_birds.gd`
- Find `_rhythm_flow_pattern_library()`
- Add a new pattern array using beat durations:
- Example tokens: `{"type": "hit", "duration_beats": 1.0}` or `{"type": "rest", "duration_beats": 0.5}`
- Durations are stored in beats and converted to seconds using `BPM`
