param(
    [ValidateSet("apk", "aab", "both")]
    [string]$Target = "both",
    [string]$ProjectPath = (Get-Location).Path,
    [string]$GodotExe = "C:\ProgrammingLanguages\gadot\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe",
    [string]$UserDataDir = ""
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "[build_android] $Message"
}

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Get-AndroidPresets([string]$CfgPath) {
    $lines = Get-Content -LiteralPath $CfgPath
    $result = @()
    $current = $null

    foreach ($lineRaw in $lines) {
        $line = $lineRaw.Trim()
        if ($line -match '^\[preset\.(\d+)\]$') {
            if ($null -ne $current) { $result += $current }
            $current = @{
                Index = [int]$matches[1]
                Name = ""
                Platform = ""
                ExportFormat = -1
            }
            continue
        }
        if ($line -match '^\[preset\.(\d+)\.options\]$') {
            continue
        }
        if ($null -eq $current) { continue }

        if ($line -match '^name="(.+)"$') {
            $current.Name = $matches[1]
            continue
        }
        if ($line -match '^platform="(.+)"$') {
            $current.Platform = $matches[1]
            continue
        }
        if ($line -match '^gradle_build/export_format=(\d+)$') {
            $current.ExportFormat = [int]$matches[1]
            continue
        }
    }
    if ($null -ne $current) { $result += $current }
    return @($result | Where-Object { $_.Platform -eq "Android" })
}

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    Fail "Project path not found: $ProjectPath"
}

$projectFile = Join-Path $ProjectPath "project.godot"
if (-not (Test-Path -LiteralPath $projectFile)) {
    Fail "project.godot not found in: $ProjectPath"
}

$exportPresets = Join-Path $ProjectPath "export_presets.cfg"
if (-not (Test-Path -LiteralPath $exportPresets)) {
    Fail "export_presets.cfg not found. Open Godot and create Android export presets first."
}

if (-not (Test-Path -LiteralPath $GodotExe)) {
    Fail "Godot console executable not found: $GodotExe"
}

if ([string]::IsNullOrWhiteSpace($UserDataDir)) {
    $UserDataDir = Join-Path $ProjectPath ".godot_userdata"
}
New-Item -ItemType Directory -Force -Path $UserDataDir | Out-Null

$buildDir = Join-Path $ProjectPath "build\android"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$apkOut = Join-Path $buildDir "adagio-music-trainer-debug.apk"
$aabOut = Join-Path $buildDir "adagio-music-trainer.aab"
$androidPresets = Get-AndroidPresets -CfgPath $exportPresets
if ($androidPresets.Count -eq 0) {
    Fail "No Android export preset found in export_presets.cfg. Create one in Godot Export menu."
}

$apkPreset = $null
$aabPreset = $null

$apkByName = $androidPresets | Where-Object { $_.Name -eq "Android APK" } | Select-Object -First 1
$aabByName = $androidPresets | Where-Object { $_.Name -eq "Android AAB" } | Select-Object -First 1
if ($null -ne $apkByName) { $apkPreset = $apkByName.Name }
if ($null -ne $aabByName) { $aabPreset = $aabByName.Name }

if ($null -eq $apkPreset) {
    $apkByFormat = $androidPresets | Where-Object { $_.ExportFormat -eq 0 } | Select-Object -First 1
    if ($null -ne $apkByFormat) { $apkPreset = $apkByFormat.Name }
}
if ($null -eq $aabPreset) {
    $aabByFormat = $androidPresets | Where-Object { $_.ExportFormat -eq 1 } | Select-Object -First 1
    if ($null -ne $aabByFormat) { $aabPreset = $aabByFormat.Name }
}

if ($null -eq $apkPreset) {
    $apkPreset = $androidPresets[0].Name
}

function Invoke-GodotExport([string]$PresetName, [string]$OutputPath, [switch]$Release) {
    $cmd = @("--headless", "--path", $ProjectPath, "--user-data-dir", $UserDataDir)
    if ($Release) {
        $cmd += @("--export-release", $PresetName, $OutputPath)
    } else {
        $cmd += @("--export-debug", $PresetName, $OutputPath)
    }

    Write-Step "Running preset '$PresetName' -> $OutputPath"
    & $GodotExe @cmd
    if ($LASTEXITCODE -ne 0) {
        Fail "Godot export failed for preset '$PresetName'. Check template install and Android SDK/JDK settings."
    }

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        Fail "Export command finished but output file not found: $OutputPath"
    }

    $item = Get-Item -LiteralPath $OutputPath
    Write-Step "Built: $($item.FullName) ($([math]::Round($item.Length / 1MB, 2)) MB)"
}

Write-Step "Project: $ProjectPath"
Write-Step "Godot: $GodotExe"
Write-Step "Target: $Target"
Write-Step "Detected Android presets: $((($androidPresets | ForEach-Object { $_.Name }) -join ', '))"

switch ($Target) {
    "apk" {
        Invoke-GodotExport -PresetName $apkPreset -OutputPath $apkOut
    }
    "aab" {
        if ([string]::IsNullOrWhiteSpace($aabPreset)) {
            Fail "No AAB-capable Android preset found. Create an Android AAB preset in Godot Export and retry."
        }
        Invoke-GodotExport -PresetName $aabPreset -OutputPath $aabOut -Release
    }
    "both" {
        Invoke-GodotExport -PresetName $apkPreset -OutputPath $apkOut
        if ([string]::IsNullOrWhiteSpace($aabPreset)) {
            Fail "APK build done, but no AAB-capable Android preset found. Add Android AAB preset in Godot Export."
        }
        Invoke-GodotExport -PresetName $aabPreset -OutputPath $aabOut -Release
    }
}

Write-Step "Done."
