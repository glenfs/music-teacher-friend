"""
Polyphonic note-detection sidecar for Clefira (Windows desktop, step 2).

Godot calls this as a subprocess:  python infer.py <wav_path>
and reads ONE line of stdout that starts with the marker "BP_RESULT ".
Everything else (basic-pitch's own prints, TF/onnx warnings) is suppressed or
goes to stderr, so the marker line is always clean JSON.

Reuses the EXACT basic-pitch ONNX pipeline validated in run_poc.py
(exact-MIDI F1 0.96 / pitch-class F1 0.99 on Clefira's piano timbre).

JSON payload:
  {
    "notes":         [midi, ...],   # octave-ghost-filtered
    "pitch_classes": [0..11, ...],  # what sight-reading grades against
    "all_detected":  [midi, ...],   # pre-filter, for debugging
    "load_ms": int, "infer_ms": int
  }
"""

import sys
import os
import io
import json
import time
import contextlib

MARKER = "BP_RESULT "

# Must match run_poc.py.
FRAME_THRESHOLD = 0.45
ONSET_THRESHOLD = 0.5
MIN_NOTE_LEN_MS = 120.0
MIN_DUR_S = 0.12
MIN_AMP = 0.10
GHOST_AMP_FRAC = 0.55


def filter_octave_ghosts(amp: dict) -> list:
    by_pc: dict = {}
    for m in amp:
        by_pc.setdefault(m % 12, []).append(m)
    kept = []
    for members in by_pc.values():
        loudest = max(amp[m] for m in members)
        for m in members:
            if amp[m] >= GHOST_AMP_FRAC * loudest:
                kept.append(m)
    return sorted(kept)


def emit(obj: dict) -> None:
    # Marker line goes to the REAL stdout (restored), one clean JSON line.
    sys.__stdout__.write(MARKER + json.dumps(obj) + "\n")
    sys.__stdout__.flush()


def main() -> int:
    if len(sys.argv) < 2:
        emit({"error": "usage: infer.py <wav_path>"})
        return 2
    wav = sys.argv[1]
    if not os.path.exists(wav):
        emit({"error": "wav not found: %s" % wav})
        return 3

    t0 = time.perf_counter()
    # Suppress basic-pitch's own stdout chatter ("Predicting MIDI for ...").
    sink = io.StringIO()
    try:
        with contextlib.redirect_stdout(sink):
            from basic_pitch.inference import predict, Model
            from basic_pitch import build_icassp_2022_model_path, FilenameSuffix
            model = Model(build_icassp_2022_model_path(FilenameSuffix.onnx))
            load_ms = (time.perf_counter() - t0) * 1000.0

            t1 = time.perf_counter()
            _out, _midi, note_events = predict(
                wav, model,
                onset_threshold=ONSET_THRESHOLD,
                frame_threshold=FRAME_THRESHOLD,
                minimum_note_length=MIN_NOTE_LEN_MS,
            )
            infer_ms = (time.perf_counter() - t1) * 1000.0
    except Exception as e:  # noqa: BLE001 -- surface any engine failure as JSON
        emit({"error": "inference failed: %s: %s" % (type(e).__name__, e)})
        return 1

    amp: dict = {}
    for ev in note_events:
        start_s, end_s, pitch = ev[0], ev[1], int(ev[2])
        a = ev[3] if len(ev) > 3 else 1.0
        if (end_s - start_s) >= MIN_DUR_S and a >= MIN_AMP:
            amp[pitch] = max(amp.get(pitch, 0.0), a)

    kept = filter_octave_ghosts(amp)
    emit({
        "notes": kept,
        "pitch_classes": sorted({m % 12 for m in kept}),
        "all_detected": sorted(amp.keys()),
        "load_ms": round(load_ms),
        "infer_ms": round(infer_ms),
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
