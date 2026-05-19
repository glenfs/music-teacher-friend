# Clefira OpenAI Icon Candidates

Validation-only asset batch. These files are not wired into `project.godot` or
`export_presets.cfg` yet.

Run from the project root after setting `OPENAI_API_KEY`:

```powershell
.\assets\icon_candidates\clefira_openai_2026_05_18\generate_icons.ps1
```

Dry run without an API key:

```powershell
.\assets\icon_candidates\clefira_openai_2026_05_18\generate_icons.ps1 -DryRun
```

Outputs will be written to:

```text
assets/icon_candidates/clefira_openai_2026_05_18/outputs
```

Asset intent:

- `clefira-app-icon-1024.png`: primary store/app icon candidate.
- `clefira-android-adaptive-background-1024.png`: adaptive icon background candidate.
- `clefira-android-adaptive-foreground-keyed-1024.png`: adaptive foreground source on a flat chroma key. Convert to transparent before wiring.
- `clefira-splash-mark-1024.png`: splash/logo mark candidate.
- `clefira-module-*.png`: home/module icon candidates.

Post-validation wiring targets:

- `export_presets.cfg` launcher icon fields.
- Android adaptive foreground/background fields.
- App splash/logo usage in the Godot UI.
- Home menu module icons, only after visual approval.
