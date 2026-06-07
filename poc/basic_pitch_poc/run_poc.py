"""
Basic Pitch polyphony proof-of-concept (desktop) -- step 1: ONNX backend.

Purpose: de-risk the ML mic-detection idea BEFORE any C++/GDExtension work.
Answers, on Clefira's OWN piano timbre:
  1. Accuracy  -- can basic-pitch recover the notes of a struck chord?
  2. Speed     -- how fast is the DEPLOYABLE (ONNX) runtime, not heavy TF?
  3. Precision -- can we trim the octave-doubling false positives?

It builds test chords by mixing the app's numbered piano samples
(assets/audio/piano/piano/<key>.mp3, where MIDI = key + 20), runs the ONNX
basic-pitch model on each, and scores detected notes against ground truth --
both raw and after a conservative octave-ghost filter.

No app code is touched. Throwaway tooling under poc/.
"""

import sys
import time
import statistics
from pathlib import Path

import numpy as np
import soundfile as sf
import librosa

REPO = Path(__file__).resolve().parents[2]
PIANO_DIR = REPO / "assets" / "audio" / "piano" / "piano"
OUT_DIR = Path(__file__).resolve().parent / "chords"
OUT_DIR.mkdir(exist_ok=True)

SR = 44100
DUR_S = 1.6
RENDER_RELEASE_S = 0.25

# basic-pitch postprocessing knobs -- the *intended* levers for cutting weak
# false positives. Raised from defaults (frame 0.3, min_note_len ~58ms) to
# suppress the short/quiet octave ghosts seen in the TF run.
FRAME_THRESHOLD = 0.45
ONSET_THRESHOLD = 0.5
MIN_NOTE_LEN_MS = 120.0

# Detection acceptance (post-model) -- ignore blips.
MIN_DUR_S = 0.12
MIN_AMP = 0.10
# Octave-ghost filter: drop a note whose pitch class is ALSO held by a clearly
# louder note (a real octave-doubling in the chord, e.g. C2+C4, will NOT be
# this lopsided, so genuine doublings survive).
GHOST_AMP_FRAC = 0.55


def midi_to_sample_path(midi: int) -> Path:
    return PIANO_DIR / f"{midi - 20}.mp3"  # key 1 == A0 == MIDI 21


def note_name(midi: int) -> str:
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return f"{names[midi % 12]}{midi // 12 - 1}"


TESTS = [
    ("single C4", [60]),
    ("single bass C2", [36]),
    ("single bass E2", [40]),
    ("single high C6", [84]),
    ("C major (C4)", [60, 64, 67]),
    ("A minor (A3)", [57, 60, 64]),
    ("G major (G3)", [55, 59, 62]),
    ("F major 1st inv", [57, 60, 65]),
    ("C major low (C3)", [48, 52, 55]),
    ("G7 dom7", [55, 59, 62, 65]),
    ("Cmaj7", [60, 64, 67, 71]),
    ("D minor (D4)", [62, 65, 69]),
    ("wide C (C2+C4+E4+G4)", [36, 60, 64, 67]),
    ("close cluster C-D-E", [60, 62, 64]),
]


def load_note(midi: int) -> np.ndarray:
    path = midi_to_sample_path(midi)
    if not path.exists():
        raise FileNotFoundError(path)
    y, _ = librosa.load(str(path), sr=SR, mono=True)
    n = int(SR * DUR_S)
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    y = y[:n].astype(np.float32)
    rel = int(SR * RENDER_RELEASE_S)
    if 0 < rel < len(y):
        y[-rel:] *= np.linspace(1.0, 0.0, rel)
    return y


def build_chord_wav(label: str, midis: list[int]) -> Path:
    mix = np.zeros(int(SR * DUR_S), dtype=np.float32)
    for m in midis:
        mix += load_note(m)
    peak = float(np.max(np.abs(mix))) or 1.0
    mix *= (0.708 / peak)  # ~ -3 dBFS
    out = OUT_DIR / (label.replace(" ", "_").replace("/", "-") + ".wav")
    sf.write(str(out), mix, SR)
    return out


def filter_octave_ghosts(notes: dict[int, float]) -> set[int]:
    """notes: {midi: amplitude}. Drop a note if a SAME pitch-class note is
    much louder (a spurious octave double), keeping genuine octave doublings
    where both are comparably loud."""
    by_pc: dict[int, list[int]] = {}
    for m in notes:
        by_pc.setdefault(m % 12, []).append(m)
    kept = set()
    for pc, members in by_pc.items():
        loudest = max(notes[m] for m in members)
        for m in members:
            if notes[m] >= GHOST_AMP_FRAC * loudest:
                kept.add(m)
    return kept


def score(detected: set[int], truth: set[int]):
    tp = len(detected & truth)
    ep = tp / len(detected) if detected else 0.0
    er = tp / len(truth) if truth else 0.0
    dpc, tpc = {m % 12 for m in detected}, {m % 12 for m in truth}
    pc_tp = len(dpc & tpc)
    pp = pc_tp / len(dpc) if dpc else 0.0
    pr = pc_tp / len(tpc) if tpc else 0.0
    return ep, er, pp, pr


def f1(p, r):
    return 0.0 if (p + r) == 0 else 2 * p * r / (p + r)


def main():
    print("Loading basic-pitch ONNX model...")
    from basic_pitch.inference import predict, Model
    from basic_pitch import build_icassp_2022_model_path, FilenameSuffix

    onnx_path = build_icassp_2022_model_path(FilenameSuffix.onnx)
    model = Model(onnx_path)  # load once; reused across clips
    print(f"Model (ONNX): {onnx_path}")
    print(f"Piano samples: {PIANO_DIR}\n")

    clips = [(label, midis, build_chord_wav(label, midis)) for label, midis in TESTS]

    def run(wav):
        return predict(
            str(wav), model,
            onset_threshold=ONSET_THRESHOLD,
            frame_threshold=FRAME_THRESHOLD,
            minimum_note_length=MIN_NOTE_LEN_MS,
        )

    run(clips[0][2])  # warmup

    header = (f"{'test':<24}{'truth':<20}{'filtered detect':<24}"
              f"{'rawF1':<7}{'filtF1':<8}{'pcF1':<6}{'ms':>6}")
    print(header)
    print("-" * len(header))

    raw_f1s, filt_f1s, pc_f1s, times = [], [], [], []
    for label, midis, wav in clips:
        t0 = time.perf_counter()
        _out, _midi, note_events = run(wav)
        dt = (time.perf_counter() - t0) * 1000.0
        times.append(dt)

        amp: dict[int, float] = {}
        dur: dict[int, float] = {}
        for ev in note_events:
            start_s, end_s, pitch = ev[0], ev[1], int(ev[2])
            a = ev[3] if len(ev) > 3 else 1.0
            d = end_s - start_s
            if d >= MIN_DUR_S and a >= MIN_AMP:
                amp[pitch] = max(amp.get(pitch, 0.0), a)
                dur[pitch] = max(dur.get(pitch, 0.0), d)

        raw = set(amp.keys())
        filtered = filter_octave_ghosts(amp)
        truth = set(midis)

        rep, rer, rpp, rpr = score(raw, truth)
        fep, fer, fpp, fpr = score(filtered, truth)
        raw_f1s.append(f1(rep, rer))
        filt_f1s.append(f1(fep, fer))
        pc_f1s.append(f1(fpp, fpr))

        truth_str = "+".join(note_name(m) for m in sorted(truth))
        filt_str = "+".join(note_name(m) for m in sorted(filtered)) or "(none)"
        print(f"{label:<24}{truth_str:<20}{filt_str:<24}"
              f"{f1(rep, rer):.2f}   {f1(fep, fer):.2f}    {f1(fpp, fpr):.2f}  {dt:5.0f}")

    print("-" * len(header))
    print(f"\nMean exact-MIDI F1 (raw model)   : {statistics.mean(raw_f1s):.2f}")
    print(f"Mean exact-MIDI F1 (ghost-filtered): {statistics.mean(filt_f1s):.2f}")
    print(f"Mean pitch-class F1               : {statistics.mean(pc_f1s):.2f}")
    print(f"ONNX inference time               : median {statistics.median(times):.0f} ms, "
          f"max {max(times):.0f} ms  (clip = {DUR_S:.1f}s audio, desktop CPU)")
    print("\nThresholds: frame={}, onset={}, min_note={}ms, ghost_frac={}".format(
        FRAME_THRESHOLD, ONSET_THRESHOLD, MIN_NOTE_LEN_MS, GHOST_AMP_FRAC))


if __name__ == "__main__":
    try:
        main()
    except ModuleNotFoundError as e:
        print(f"\nMissing dependency: {e.name}", file=sys.stderr)
        sys.exit(2)
