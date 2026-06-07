# Basic Pitch polyphony PoC (desktop)

Throwaway spike to decide whether an ML mic-detection path is worth the
cross-platform (Android) integration effort. **No app code is touched.**

## What it does
Builds chords by mixing Clefira's own numbered piano samples
(`assets/audio/piano/piano/<key>.mp3`, MIDI = key + 20), runs
[Spotify Basic Pitch](https://github.com/spotify/basic-pitch) (Apache-2.0) on
each, and scores detected notes vs. ground truth.

## Run
```powershell
python -m pip install basic-pitch onnxruntime soundfile librosa
python poc/basic_pitch_poc/run_poc.py
```

## Reading the output
- **exactP/R** — precision/recall on exact MIDI (octave-sensitive).
- **pcP/R** — pitch-class precision/recall (octave-agnostic). A big
  pcF1 ≫ exactF1 gap means octave errors (the known bass/harmonic problem).
- **ms** — per-clip inference time, **desktop**. Phone is slower; treat as a
  lower bound, not the shipping number.

## Decision gate
- Good accuracy + sane speed → proceed to the in-Godot take-based path
  (ONNX GDExtension on Windows first, then Android).
- Poor accuracy on our timbre → stop; keep MIDI as the exact path and the
  YIN mono mic + polyphony-rejection as the acoustic fallback.
