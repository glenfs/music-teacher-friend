# Upright Piano 3D Asset

This folder contains a generated low-poly upright piano model for Godot.

Files:
- `upright_piano.glb`: Godot-importable glTF binary model.
- `upright_piano_preview.tscn`: Lightweight preview scene with camera and lighting.
- `generate_upright_piano_glb.py`: Source generator for rebuilding the model.

Model notes:
- The keyboard has 88 separate key nodes.
- Key node names include the project piano sample index and MIDI note, for example `key_040_C4_midi60`.
- The sample index mapping follows the project rule: `1 => A0 (MIDI 21)`, so `40 => C4`.
- Materials are flat PBR colors intended to read cleanly in a stylized music-learning scene.

Regenerate:

```powershell
python assets/models/piano/generate_upright_piano_glb.py
```
