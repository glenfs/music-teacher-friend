# Polyphony — native ONNX note detection (GDExtension)

Unified C++ GDExtension that runs Spotify **Basic Pitch** (Apache-2.0) via
**ONNX Runtime** to transcribe chords from a recorded take. One codebase targets
**Windows + Android**; it replaces the desktop Python sidecar
(`poc/basic_pitch_poc/`) used to validate the approach.

Why this exists: YIN is monophonic — a struck chord reads as one note. This
model returns ALL played notes (validated: exact-MIDI F1 0.96, pitch-class F1
0.99 on Clefira's piano timbre).

## Model I/O (`models/nmp.onnx`, 230 KB)
- **Input**  `serving_default_input_2:0` — `[n_windows, 43844, 1]` float, mono 22050 Hz.
  Raw audio; the CQT/harmonic-stacking is baked into the graph (no spectrogram in C++).
- **Outputs** `StatefulPartitionedCall:2` & `:1` → `[n,172,88]` (note / onset),
  `:0` → `[n,172,264]` (contour).

## Pipeline (per take)
1. **Preprocess** — resample to 22050, mono, overlapped windows of 43844 samples
   (overlap 30 frames). ~50 lines.
2. **Infer** — ORT session over the windows → 3 posteriorgrams.
3. **Postprocess** — port of basic-pitch `note_creation.py`: unwrap overlap,
   threshold onsets/frames, infer note events, octave-ghost filter. ~200 lines —
   the real work.

## Phase roadmap
- [x] **A — ORT runs the model in C++**, bit-exact vs Python (`standalone_parity`,
      worst |diff| 2e-07). Proves toolchain + runtime + model on Windows.
- [x] **B — Postprocess ported to C++** (`postprocess.{h,cpp}`), validated vs Python:
      `phaseB_test` — exact on reference tensors, ±1 frame end-to-end (`PHASE_B PASS`).
      Gotcha: `get_infered_onsets` runs in **float64** in numpy (untyped `np.zeros`);
      porting it in float32 splits a held-note onset plateau (boundary off by 1).
      (Preprocess audio→windows still TODO — fixtures use the dumped windowed input.)
- [x] **C — godot-cpp GDExtension** `PolyphonyDetector` (`detect_samples(samples,
      rate) -> {notes, pitch_classes, infer_ms}`). Verified in headless Godot:
      raw 44.1k samples -> correct notes (`GDEXT_RESULT PASS`, ~120 ms/clip).
      Preprocess (resample+window) ported. Built vs the 4.6 engine's dumped API
      (`GODOTCPP_CUSTOM_API_FILE`). New `.gdextension` registers on editor scan;
      a headless `--script` run needs `.godot/extension_list.cfg` present (run
      `--editor --quit` once after a fresh checkout).
- [x] **D — Android arm64 build** with `onnxruntime-android` (1.22.0 AAR) + NDK 27.1.
      Same C++ source; CMake branches ORT (Windows .lib/.dll vs Android headers/.so)
      and skips the desktop test exes. Produces `libpolyphony.android.arm64-v8a.so`
      (verified ELF64/AArch64, exports `polyphony_library_init`, NEEDs libonnxruntime.so).
      `.gdextension` has `android.{debug,release}.arm64` entries + `libonnxruntime.so` dep.
      Gotcha: `Ort::Session` path is `wchar_t*` on Windows, `char*` on Android — `#ifdef _WIN32`.
      **On-device execution still unverified** (needs a device/emulator).

## Build (Phase C, Windows GDExtension)
```powershell
git clone --depth 1 https://github.com/godotengine/godot-cpp.git godot-cpp
mkdir godot_api; cd godot_api
& $Godot --headless --dump-extension-api --dump-gdextension-interface; cd ..
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release --target polyphony   # -> addons/polyphony/bin/*.dll
& $Godot --headless --editor --quit --path ../..          # register the extension
& $Godot --headless --path ../.. --script res://poc/basic_pitch_poc/godot_gdext_test.gd
```

## Build (Phase D, Android arm64)
```powershell
# onnxruntime-android AAR (zip) -> third_party/onnxruntime-android/ (headers + jni/<abi>/libonnxruntime.so)
$NDK   = "$env:LOCALAPPDATA\Android\Sdk\ndk\27.1.12297006"
$NINJA = "$env:LOCALAPPDATA\Android\Sdk\cmake\3.22.1\bin\ninja.exe"
cmake -S . -B build_android -G Ninja -DCMAKE_MAKE_PROGRAM="$NINJA" `
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" `
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DCMAKE_BUILD_TYPE=Release
cmake --build build_android --target polyphony   # -> addons/polyphony/bin/libpolyphony.android.arm64-v8a.so
```
Then export the APK (`build_android.ps1`); Godot bundles the `.so` + `libonnxruntime.so`
into `lib/arm64-v8a/` from the `.gdextension` entries.

## Build (Windows, Phase A)
```powershell
# one-time: download + extract ORT (gitignored)
curl -sL -o third_party/onnxruntime-win-x64.zip `
  https://github.com/microsoft/onnxruntime/releases/download/v1.20.1/onnxruntime-win-x64-1.20.1.zip
Expand-Archive third_party/onnxruntime-win-x64.zip third_party/

cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
./build/Release/standalone_parity.exe . "C_major_(C4)"   # -> PARITY PASS
```

Regenerate parity fixtures: `…/poc/basic_pitch_poc/.venv/Scripts/python.exe dump_reference.py <wav>`

## Licenses (add to assets/LICENSES.md before shipping)
- Basic Pitch model (`nmp.onnx`) — Apache-2.0 (Spotify)
- ONNX Runtime — MIT (Microsoft)
