# Salamander Grand Piano Setup

How to swap Clefira's piano sample bank for **Salamander Grand Piano V3** by Alexander Holm (CC-BY 3.0 — free for commercial use with attribution).

## Why

- The original sample bank was tagged `TBD` in `LICENSES.md` — a ship blocker.
- Salamander is the de-facto free professional piano library: Yamaha C5 concert grand, recorded with multiple velocity layers. Used by MuseScore, Carla, dozens of indie music apps.
- One attribution line in `LICENSES.md` + your store page is all the licensing requires.

## Prerequisites

1. **ffmpeg** on `PATH` — download from https://ffmpeg.org/download.html, install, confirm `ffmpeg -version` works in a fresh PowerShell window.
2. **~2 GB free disk** during conversion (the source archive is ~700 MB; converted output is ~50 MB).

## Step 1 — Download Salamander V3

1. Open https://archive.org/details/SalamanderGrandPianoV3
2. In the *Download Options* sidebar, look for an OGG package — typically `SalamanderGrandPianoV3.ogg.tar.bz2` or `SalamanderGrandPianoV3_48khz24bit_ogg.tar.bz2`. Avoid the SFZ-only download (that's a patch definition without samples).
3. Save to your Downloads folder. **The download is ~700 MB and may take 10–30 minutes** depending on your connection.
4. Extract the archive (7-Zip handles `.tar.bz2`). After extraction you should see a folder with files named like `A0v1.ogg`, `A0v2.ogg`, … `C8v16.ogg`. **That's the folder you'll point the script at.**

## Step 2 — Run the conversion script

From the project root in PowerShell:

```powershell
# Dry run first to confirm the script sees your samples correctly:
.\scripts\tools\fetch_salamander.ps1 -Source "C:\Downloads\SalamanderGrandPianoV3\samples" -DryRun

# If the dry run reports "Found samples for 88 distinct notes" — run for real:
.\scripts\tools\fetch_salamander.ps1 -Source "C:\Downloads\SalamanderGrandPianoV3\samples"
```

Expected runtime: **~3–8 minutes** (ffmpeg re-encodes 88 OGG files to MP3).

### Velocity layer choice

Salamander samples each note at 16 dynamic levels (`v1` = quietest, `v16` = loudest). The script defaults to `v9` (just above mezzo-forte) — a balanced practice sound that's neither too quiet nor too bright.

To pick a different layer:

```powershell
.\scripts\tools\fetch_salamander.ps1 -Source "..." -Velocity 7   # softer, intimate
.\scripts\tools\fetch_salamander.ps1 -Source "..." -Velocity 11  # brighter, more present
```

Recommended range: `6` to `12`. Below 6 sounds dead in practice contexts; above 12 is too brilliant for casual play.

## Step 3 — Verify in Godot

1. Open the Godot editor on the project. It will detect the changed MP3 files and re-import them automatically (takes 30–60 seconds; watch the bottom output panel).
2. Run smoke QA:
   ```powershell
   .\qa_run.ps1 -Scope smoke
   ```
3. Manually play a few notes via Chord Explorer or the virtual piano in Practice Drills to confirm they sound right (warm grand-piano tone, not muffled or distorted).

## If something goes wrong

### Reverting

The script automatically backs up your previous samples to `assets/audio/piano/piano_backup_pre_salamander/` on first run. To restore them:

```powershell
.\scripts\tools\fetch_salamander.ps1 -Restore
```

### Common issues

| Symptom | Cause | Fix |
|---|---|---|
| "ffmpeg not found on PATH" | ffmpeg not installed or PowerShell session predates the install | Install ffmpeg, close + reopen PowerShell |
| "No .ogg/.wav files found in <Source>" | Pointed at archive root instead of the samples subfolder | Look one level deeper for files named `A0v1.ogg` etc. |
| "Found audio files but none matched expected naming" | Different Salamander mirror with non-standard filenames | Open an issue — script regex may need extending |
| Notes sound boomy / too quiet | Velocity layer choice doesn't suit your monitoring | Re-run with `-Velocity 7` or `-Velocity 11` |
| Godot doesn't see the change | Editor was open during the swap and cached imports | Close + reopen Godot, or delete `.import` files in `assets/audio/piano/piano/` |

## License compliance

Already handled in `LICENSES.md`. The CC-BY 3.0 attribution requirement is satisfied by:

1. The entry in `LICENSES.md` (technical compliance)
2. A line in the app's About / Credits screen (recommended for user-visible attribution): *"Piano: Salamander Grand Piano by Alexander Holm — CC-BY 3.0"*
3. A line in the store page Description / Credits section

The store-page attribution is the one most-often forgotten — add it to your launch checklist.

## What the script doesn't do (yet)

- **Multi-velocity playback** — the project's `PIANO_NUMBERED_DIR` loader expects one file per note. Adding true velocity-layer playback (where MIDI velocity selects a different sample) is a deeper architecture change; not on the immediate roadmap.
- **Release samples / sustain pedal samples** — Salamander includes these but the current audio engine doesn't consume them.
- **Sample optimization for mobile** — the ~50 MB MP3 bank is fine for desktop but adds noticeably to Android APK size. If APK size becomes a problem, consider a 44.1 kHz / 96 kbps re-encode or shipping only A1–C7 (drop the lowest/highest octaves).
