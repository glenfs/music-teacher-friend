"""
Dump model I/O + the reference note_events for the C++ Phase-B port to validate
against. Writes raw float32 .bin (C order) + meta.json per clip.

Per clip <name>:
  <name>.input.bin            windowed model input  (n_win, 43844, 1)
  <name>.note.bin             unwrapped 'note' frames (n_times, 88)
  <name>.onset.bin            unwrapped 'onset'        (n_times, 88)
  <name>.meta.json            shapes, params, reference note_events

note_events are the FRAME-DOMAIN tuples from output_to_notes_polyphonic
(start_frame, end_frame, midi, amplitude) -- the exact output the C++ port
must reproduce.

Run with the PoC venv.
"""
import sys
import json
from pathlib import Path

import numpy as np

from basic_pitch import build_icassp_2022_model_path, FilenameSuffix
import basic_pitch.constants as C
from basic_pitch.inference import Model, get_audio_input, unwrap_output
import basic_pitch.note_creation as nc

HERE = Path(__file__).resolve().parent
OUT = HERE / "testdata"
OUT.mkdir(exist_ok=True)
CHORDS = HERE.parent.parent / "poc" / "basic_pitch_poc" / "chords"

# Match infer.py / run_poc.py
ONSET_THRESH = 0.5
FRAME_THRESH = 0.45
MIN_NOTE_LEN_MS = 120.0
N_OVERLAP = 30

_model = None


def model():
    global _model
    if _model is None:
        _model = Model(build_icassp_2022_model_path(FilenameSuffix.onnx))
    return _model


def render_chord(name, midis, dur_s):
    import soundfile as sf
    import librosa
    sr = 44100
    mix = np.zeros(int(sr * dur_s), dtype=np.float32)
    for m in midis:
        y, _ = librosa.load(str(CHORDS.parent / "chords" / ("%d.mp3" % 0)), sr=sr) if False else (None, None)
    # build from app piano samples directly
    piano = HERE.parent.parent / "assets" / "audio" / "piano" / "piano"
    for m in midis:
        y, _ = librosa.load(str(piano / ("%d.mp3" % (m - 20))), sr=sr, mono=True)
        n = int(sr * dur_s)
        y = np.pad(y, (0, max(0, n - len(y))))[:n]
        rel = int(sr * 0.25)
        y[-rel:] *= np.linspace(1, 0, rel)
        mix += y
    mix *= 0.708 / (np.max(np.abs(mix)) or 1.0)
    p = CHORDS / (name + ".wav")
    sf.write(str(p), mix, sr)
    return p


def dump(name, wav):
    overlap_len = N_OVERLAP * C.FFT_HOP
    hop = C.AUDIO_N_SAMPLES - overlap_len

    out = {"note": [], "onset": [], "contour": []}
    orig_len = None
    windows = []
    for w, _, original_length in get_audio_input(str(wav), overlap_len, hop):
        windows.append(w[0])
        for k, v in model().predict(w).items():
            out[k].append(v)
        orig_len = original_length
    inp = np.stack(windows, axis=0).astype(np.float32)

    note = unwrap_output(np.concatenate(out["note"]), orig_len, N_OVERLAP)
    onset = unwrap_output(np.concatenate(out["onset"]), orig_len, N_OVERLAP)

    min_note_len = int(np.round(MIN_NOTE_LEN_MS / 1000 * (C.AUDIO_SAMPLE_RATE / C.FFT_HOP)))
    events = nc.output_to_notes_polyphonic(
        note.astype(np.float32), onset.astype(np.float32),
        onset_thresh=ONSET_THRESH, frame_thresh=FRAME_THRESH,
        min_note_len=min_note_len, infer_onsets=True,
        max_freq=None, min_freq=None, melodia_trick=True,
    )

    inp.tofile(OUT / f"{name}.input.bin")
    np.ascontiguousarray(note.astype(np.float32)).tofile(OUT / f"{name}.note.bin")
    np.ascontiguousarray(onset.astype(np.float32)).tofile(OUT / f"{name}.onset.bin")
    meta = {
        "name": name, "wav": str(wav),
        "n_windows": int(inp.shape[0]), "original_length": int(orig_len),
        "n_times": int(note.shape[0]), "n_freq": int(note.shape[1]),
        "frames_per_window": int(np.concatenate(out["note"]).shape[1]),
        "n_overlap": N_OVERLAP, "min_note_len": min_note_len,
        "onset_thresh": ONSET_THRESH, "frame_thresh": FRAME_THRESH,
        "note_events": [[int(s), int(e), int(p), float(a)] for (s, e, p, a) in events],
    }
    (OUT / f"{name}.meta.json").write_text(json.dumps(meta, indent=2))
    # Flat sidecars so the C++ test needs no JSON parser.
    #   dims.txt: n_windows n_times n_freq frames_per_window n_overlap original_length min_note_len onset_thresh frame_thresh
    (OUT / f"{name}.dims.txt").write_text("%d %d %d %d %d %d %d %g %g\n" % (
        meta["n_windows"], meta["n_times"], meta["n_freq"], meta["frames_per_window"],
        meta["n_overlap"], meta["original_length"], meta["min_note_len"],
        meta["onset_thresh"], meta["frame_thresh"]))
    with open(OUT / f"{name}.events.txt", "w") as f:
        for s, e, p, a in events:
            f.write("%d %d %d %.7f\n" % (int(s), int(e), int(p), float(a)))
    print(f"{name}: windows={inp.shape[0]} n_times={note.shape[0]} events={len(events)} -> "
          f"{sorted(set(p for _,_,p,_ in events))}")


def main():
    cases = [
        ("C_major_(C4)", [60, 64, 67], 1.6),
        ("G7_dom7", [55, 59, 62, 65], 1.6),
        ("single_bass_E2", [40], 1.6),
        ("Cmaj_long_4s", [48, 52, 55, 60], 4.0),  # multi-window: exercises unwrap concat
    ]
    for name, midis, dur in cases:
        wav = CHORDS / (name + ".wav")
        if not wav.exists():
            wav = render_chord(name, midis, dur)
        dump(name, wav)


if __name__ == "__main__":
    main()
