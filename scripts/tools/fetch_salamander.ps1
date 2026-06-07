# fetch_salamander.ps1
# -------------------------------------------------------------------------
# Replaces the project's piano sample bank with notes converted from the
# Salamander Grand Piano V3 library by Alexander Holm (CC-BY 3.0).
#
# Salamander samples 88 notes (A0..C8) at 16 velocity layers each. For
# Clefira's single-layer file convention we pick ONE velocity layer per note
# and write it to assets/audio/piano/piano/<n>.mp3 where n = 1..88
# (1 = A0 / MIDI 21, 88 = C8 / MIDI 108).
#
# WHY MANUAL DOWNLOAD: the full archive is ~700 MB. PowerShell IWR over an
# Archive.org redirect is fragile. Download once in a browser, point this
# script at the extracted folder, and re-run if anything goes wrong.
#
# PREREQS:
#   - ffmpeg on PATH                        (https://ffmpeg.org/download.html)
#   - Salamander V3 archive extracted to a folder containing the per-note
#     OGG/WAV samples. Get it from:
#       https://archive.org/details/SalamanderGrandPianoV3
#     Look for "SalamanderGrandPianoV3" or similar; pick the OGG package
#     ("48khz24bit" is common). Extract until you see files like A0v8.ogg.
#
# USAGE:
#   ./fetch_salamander.ps1 -Source "C:\path\to\Salamander\samples"
#   ./fetch_salamander.ps1 -Source "..." -Velocity 9       # pick layer
#   ./fetch_salamander.ps1 -Source "..." -DryRun           # plan, no writes
#   ./fetch_salamander.ps1 -Restore                        # undo from backup
#
# VELOCITY LAYER CHOICES (Salamander uses v1=quietest, v16=loudest):
#   v6-v7  : piano   - intimate practice feel, less brilliant
#   v8-v9  : mezzo   - recommended default; clear without being bright
#   v10-v12: forte   - more presence, bigger sound (consumes more headroom)
# -------------------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Source = "",

    [Parameter(Mandatory = $false)]
    [int]$Velocity = 9,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Restore,

    [Parameter(Mandatory = $false)]
    [int]$MP3BitrateKbps = 160
)

$ErrorActionPreference = 'Stop'

# ---- Project paths -------------------------------------------------------
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$pianoDir    = Join-Path $projectRoot "assets\audio\piano\piano"
$backupDir   = Join-Path $projectRoot "assets\audio\piano\piano_backup_pre_salamander"

if (-not (Test-Path $pianoDir)) {
    throw "Project piano dir not found: $pianoDir"
}

# ---- Restore mode --------------------------------------------------------
if ($Restore) {
    if (-not (Test-Path $backupDir)) {
        throw "No backup folder found at: $backupDir"
    }
    Write-Host "Restoring original samples from $backupDir ..." -ForegroundColor Yellow
    Get-ChildItem $backupDir -Filter "*.mp3" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $pianoDir $_.Name) -Force
    }
    Write-Host "Restore complete. Original samples reinstated." -ForegroundColor Green
    return
}

# ---- Validate normal-mode args ------------------------------------------
if ([string]::IsNullOrWhiteSpace($Source)) {
    throw "Specify -Source <path to extracted Salamander folder>. See script header for download instructions."
}
if (-not (Test-Path $Source)) {
    throw "Source folder not found: $Source"
}
if ($Velocity -lt 1 -or $Velocity -gt 16) {
    throw "Velocity must be 1..16 (Salamander velocity layers)."
}

# ---- ffmpeg check --------------------------------------------------------
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) {
    throw "ffmpeg not found on PATH. Install from https://ffmpeg.org/download.html and ensure 'ffmpeg' is callable."
}

# ---- MIDI <-> note mapping ----------------------------------------------
# File index 1 = A0 = MIDI 21. File index N = MIDI (20 + N). Range 1..88.
$noteLetters = @("C","C#","D","D#","E","F","F#","G","G#","A","A#","B")

function MidiToSalamanderName([int]$midi) {
    # Salamander typically uses sharps (A#) not flats (Bb). Octave per MIDI
    # convention: MIDI 60 = C4 (middle C).
    $pc      = $midi % 12
    $octave  = [math]::Floor($midi / 12) - 1
    $letter  = $noteLetters[$pc]
    return "$letter$octave"
}

# ---- Scan source for samples --------------------------------------------
# Salamander V3 only samples every minor third (A/C/D#/F# per octave). For
# chromatic notes between samples, we pitch-shift the nearest sample by
# +/-1 semitone using ffmpeg's asetrate filter.
Write-Host "Scanning $Source for Salamander samples..." -ForegroundColor Cyan
$allSamples = Get-ChildItem -Path $Source -Recurse -Include *.ogg, *.wav -File

if ($allSamples.Count -eq 0) {
    throw "No .ogg/.wav files found in $Source (searched recursively). Wrong folder?"
}

# Build map: midi -> @{ velocity -> filepath }
$midiMap = @{}
$rxNote  = '^(A|C|D#|F#)(-?\d+)v(\d+)\.(ogg|wav)$'

# Map pitch class (only sampled ones)
$pcOfLetter = @{ "C" = 0; "D#" = 3; "F#" = 6; "A" = 9 }

foreach ($f in $allSamples) {
    $name = $f.Name
    # Skip Salamander's non-note files: harmL*, harmS*, harmV3*, pedal*, rel*
    if ($name -match '^(harmL|harmS|harmV3|pedalU|pedalD|rel\d)') { continue }

    $match = [regex]::Match($name, $rxNote, 'IgnoreCase')
    if (-not $match.Success) { continue }

    $letter = $match.Groups[1].Value.ToUpper()
    $octave = [int]$match.Groups[2].Value
    $vel    = [int]$match.Groups[3].Value
    if (-not $pcOfLetter.ContainsKey($letter)) { continue }

    # MIDI = (octave + 1) * 12 + pitch_class
    $midi = ($octave + 1) * 12 + $pcOfLetter[$letter]

    if (-not $midiMap.ContainsKey($midi)) {
        $midiMap[$midi] = @{}
    }
    $midiMap[$midi][$vel] = $f.FullName
}

if ($midiMap.Count -eq 0) {
    throw @"
Found audio files but none matched expected Salamander naming pattern.
Expected: A0v1.wav, A0v2.wav, ..., C8v16.wav (or .ogg variants).
Sample names found: $($allSamples | Select-Object -First 5 | ForEach-Object { $_.Name } | Join-String -Separator ', ')
Check that you downloaded the per-note OGG or WAV package, not a single SFZ patch.
"@
}

Write-Host "Found samples for $($midiMap.Count) distinct MIDI pitches (Salamander V3 samples every 3 semitones; chromatic notes are pitch-shifted)." -ForegroundColor Cyan

# ---- Backup current samples ---------------------------------------------
if (-not $DryRun) {
    if (-not (Test-Path $backupDir)) {
        Write-Host "Creating backup at $backupDir ..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Get-ChildItem $pianoDir -Filter "*.mp3" | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $backupDir $_.Name) -Force
        }
        Write-Host "Backed up $((Get-ChildItem $backupDir -Filter '*.mp3').Count) original samples." -ForegroundColor Green
    } else {
        Write-Host "Backup folder already exists; keeping prior backup intact." -ForegroundColor Gray
    }
}

# ---- Convert + write -----------------------------------------------------
$converted = 0
$missing   = New-Object System.Collections.Generic.List[string]
$fallbacks = New-Object System.Collections.Generic.List[string]

$sampledMidis = $midiMap.Keys | Sort-Object

for ($idx = 1; $idx -le 88; $idx++) {
    $targetMidi = 20 + $idx
    $targetMp3  = Join-Path $pianoDir "$idx.mp3"

    # Find nearest sampled MIDI (within +/-2 semitones).
    $nearest = $sampledMidis | Sort-Object { [math]::Abs($_ - $targetMidi) } | Select-Object -First 1
    if ($null -eq $nearest) {
        $missing.Add("$idx (MIDI $targetMidi)")
        continue
    }
    $semitones = $targetMidi - $nearest
    if ([math]::Abs($semitones) -gt 2) {
        $absSemi = [math]::Abs($semitones)
        $missing.Add("$idx (MIDI $targetMidi, nearest sample is $absSemi semitones away - skipping)")
        continue
    }

    $velMap = $midiMap[$nearest]

    # Pick the requested velocity, or the closest available.
    $picked = $null
    $pickedVel = -1
    if ($velMap.ContainsKey($Velocity)) {
        $picked = $velMap[$Velocity]
        $pickedVel = $Velocity
    } else {
        $available = $velMap.Keys | Sort-Object { [math]::Abs($_ - $Velocity) }
        $pickedVel = $available | Select-Object -First 1
        $picked = $velMap[$pickedVel]
        $fallbacks.Add("MIDI ${targetMidi}: asked v$Velocity, used v$pickedVel")
    }

    if ($DryRun) {
        $converted++
        continue
    }

    # Build ffmpeg filter. asetrate changes pitch + speed; aresample restores
    # sample rate. For piano (notes decay naturally) the slight duration
    # change from +/-1 semitone shift is inaudible.
    $filter = ""
    if ($semitones -eq 0) {
        $filter = "aresample=44100"
    } else {
        $newRate = [int](44100.0 * [math]::Pow(2.0, $semitones / 12.0))
        $filter = "asetrate=$newRate,aresample=44100"
    }

    & ffmpeg -y -loglevel error -i $picked -af $filter -codec:a libmp3lame -b:a "${MP3BitrateKbps}k" $targetMp3
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ffmpeg failed for MIDI $targetMidi -> $targetMp3" -ForegroundColor Red
        continue
    }
    $converted++
    if (($converted % 12) -eq 0) {
        Write-Host "  converted $converted / 88" -ForegroundColor Gray
    }
}

# ---- Report -------------------------------------------------------------
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "DRY RUN - no files written." -ForegroundColor Yellow
}
Write-Host "Notes converted:    $converted / 88" -ForegroundColor Green
if ($missing.Count -gt 0) {
    Write-Host "Notes NOT found in source ($($missing.Count)):" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "  Original backup files remain in place for missing notes." -ForegroundColor Gray
}
if ($fallbacks.Count -gt 0) {
    Write-Host "Velocity fallbacks ($($fallbacks.Count)) - exact v$Velocity unavailable:" -ForegroundColor Yellow
    $fallbacks | Select-Object -First 5 | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    if ($fallbacks.Count -gt 5) {
        Write-Host "  ... and $($fallbacks.Count - 5) more" -ForegroundColor Yellow
    }
}
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Open Godot, let it re-import the updated MP3s." -ForegroundColor White
Write-Host "  2. Run: .\qa_run.ps1 -Scope smoke" -ForegroundColor White
Write-Host "  3. Manually play a few notes in Chord Explorer or Practice Drills." -ForegroundColor White
Write-Host "  4. If unhappy with the sound, re-run with a different -Velocity (6..12 range)." -ForegroundColor White
Write-Host "  5. To revert: .\fetch_salamander.ps1 -Restore" -ForegroundColor White
Write-Host "==================================================" -ForegroundColor Cyan
