# build_student_releases.ps1
# -------------------------------------------------------------------------
# Exports the Student SKU for Windows desktop + Android in one run.
#
# Outputs:
#   builds/windows/student/ClefiraStudent.exe   (and .pck sidecar)
#   builds/android/student/ClefiraStudent.apk
#
# USAGE:
#   .\tools\build_student_releases.ps1                       # both, release Win + debug APK
#   .\tools\build_student_releases.ps1 -Target Windows       # Windows only
#   .\tools\build_student_releases.ps1 -Target Android       # Android only
#   .\tools\build_student_releases.ps1 -AndroidRelease       # release APK (needs signed keystore configured)
#   .\tools\build_student_releases.ps1 -GodotPath "C:\path\to\Godot.exe"
#
# PREREQS:
#   - Windows export templates installed for Godot 4.6 (Editor > Manage Export Templates)
#   - Android SDK + JDK paths configured in Godot Editor Settings > Export > Android
#   - For -AndroidRelease: release keystore configured in Editor Settings (keys/adagio-release.jks)
# -------------------------------------------------------------------------

[CmdletBinding()]
param(
    [ValidateSet("Windows", "Android", "Both")]
    [string]$Target = "Both",

    [string]$GodotPath = "C:\ProgrammingLanguages\gadot\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe",

    [switch]$WindowsDebug,
    [switch]$AndroidRelease,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# ---- Locate project root ------------------------------------------------
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$projectGodot = Join-Path $ProjectRoot "project.godot"
if (-not (Test-Path -LiteralPath $projectGodot)) {
    throw "project.godot not found at $ProjectRoot"
}

$exportPresets = Join-Path $ProjectRoot "export_presets.cfg"
if (-not (Test-Path -LiteralPath $exportPresets)) {
    throw "export_presets.cfg not found at $ProjectRoot"
}

# ---- Locate Godot -------------------------------------------------------
function Resolve-Godot {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath) -and (Test-Path -LiteralPath $RequestedPath)) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN) -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }
    foreach ($name in @("godot4", "godot")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    throw "Godot executable not found. Pass -GodotPath or set GODOT_BIN env var."
}

$GodotExe = Resolve-Godot -RequestedPath $GodotPath

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Clefira Student Release Builder" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Project: $ProjectRoot"
Write-Host "Godot:   $GodotExe"
Write-Host "Target:  $Target"
Write-Host ""

# ---- Export helper ------------------------------------------------------
function Invoke-Export {
    param(
        [string]$PresetName,
        [string]$OutputPath,
        [bool]$ReleaseBuild
    )

    $outDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    if ($Clean -and (Test-Path -LiteralPath $outDir)) {
        Write-Host "Cleaning $outDir ..." -ForegroundColor DarkGray
        Get-ChildItem -LiteralPath $outDir -Force |
            Where-Object { $_.Name -ne ".gitkeep" } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    $exportArg = if ($ReleaseBuild) { "--export-release" } else { "--export-debug" }
    $modeLabel = if ($ReleaseBuild) { "release" } else { "debug" }

    Write-Host ">> Exporting [$modeLabel] '$PresetName' -> $OutputPath" -ForegroundColor Yellow
    $start = Get-Date

    & $GodotExe --headless --path $ProjectRoot $exportArg $PresetName $OutputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed for preset '$PresetName' (exit code $LASTEXITCODE)."
    }
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "Export reported success but file not found: $OutputPath"
    }

    $elapsed = ((Get-Date) - $start).TotalSeconds
    $size = (Get-Item -LiteralPath $OutputPath).Length
    $sizeMB = [math]::Round($size / 1MB, 2)
    Write-Host ("   OK  ${sizeMB} MB in {0:N1}s" -f $elapsed) -ForegroundColor Green
    Write-Host ""

    return @{
        Preset = $PresetName
        Path   = $OutputPath
        SizeMB = $sizeMB
        Mode   = $modeLabel
    }
}

# ---- Build the requested targets ----------------------------------------
$results = @()
$failures = @()

if ($Target -eq "Windows" -or $Target -eq "Both") {
    try {
        $r = Invoke-Export `
            -PresetName "Windows Desktop - Student" `
            -OutputPath (Join-Path $ProjectRoot "builds\windows\student\ClefiraStudent.exe") `
            -ReleaseBuild (-not $WindowsDebug.IsPresent)
        $results += $r
    } catch {
        $failures += "Windows: $_"
        Write-Host "   FAILED: $_" -ForegroundColor Red
        Write-Host ""
    }
}

if ($Target -eq "Android" -or $Target -eq "Both") {
    try {
        $r = Invoke-Export `
            -PresetName "Android - Student" `
            -OutputPath (Join-Path $ProjectRoot "builds\android\student\ClefiraStudent.apk") `
            -ReleaseBuild $AndroidRelease.IsPresent
        $results += $r
    } catch {
        $failures += "Android: $_"
        Write-Host "   FAILED: $_" -ForegroundColor Red
        Write-Host ""
    }
}

# ---- Report -------------------------------------------------------------
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
if ($results.Count -eq 0) {
    Write-Host "No artifacts produced." -ForegroundColor Red
} else {
    foreach ($r in $results) {
        Write-Host ("  [{0,-7}] {1,-32} -> {2} MB" -f $r.Mode, $r.Preset, $r.SizeMB) -ForegroundColor Green
        Write-Host ("            {0}" -f $r.Path) -ForegroundColor Gray
    }
}
if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Failures:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    exit 1
}
Write-Host ""
exit 0
