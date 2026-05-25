param(
    [ValidateSet("Teacher", "Student", "All")]
    [string]$Sku = "All",

    [string]$GodotPath = $env:GODOT_BIN,

    [switch]$DebugExport,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildRoot = Join-Path $ProjectRoot "builds\windows"

function Resolve-GodotCommand {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }
        $cmd = Get-Command $RequestedPath -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
        throw "Godot executable not found at '$RequestedPath'. Pass -GodotPath or set GODOT_BIN."
    }

    foreach ($candidate in @("godot4", "godot")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }

    throw "Godot executable not found. Add Godot to PATH, set GODOT_BIN, or pass -GodotPath 'C:\Path\To\Godot.exe'."
}

function Clear-BuildDirectory {
    param([string]$TargetDir)

    $resolvedRoot = (Resolve-Path -LiteralPath $BuildRoot).Path
    if (-not (Test-Path -LiteralPath $TargetDir)) {
        return
    }
    $resolvedTarget = (Resolve-Path -LiteralPath $TargetDir).Path
    if (-not $resolvedTarget.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean outside builds\windows: $resolvedTarget"
    }

    Get-ChildItem -LiteralPath $TargetDir -Force |
        Where-Object { $_.Name -ne ".gitkeep" } |
        Remove-Item -Recurse -Force
}

function Invoke-WindowsExport {
    param(
        [string]$GodotExe,
        [string]$PresetName,
        [string]$OutputPath
    )

    $outDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    if ($Clean) {
        Clear-BuildDirectory -TargetDir $outDir
    }

    $exportArg = if ($DebugExport) { "--export-debug" } else { "--export-release" }
    $args = @(
        "--headless",
        "--path", $ProjectRoot,
        $exportArg, $PresetName, $OutputPath
    )

    Write-Host "Exporting $PresetName -> $OutputPath"
    & $GodotExe @args
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed for preset '$PresetName' with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "project.godot"))) {
    throw "Could not find project.godot at $ProjectRoot"
}

$GodotExe = Resolve-GodotCommand -RequestedPath $GodotPath

$targets = @()
if ($Sku -eq "Teacher" -or $Sku -eq "All") {
    $targets += @{
        Preset = "Windows Desktop - Teacher"
        Output = Join-Path $BuildRoot "teacher\ClefiraTeacher.exe"
    }
}
if ($Sku -eq "Student" -or $Sku -eq "All") {
    $targets += @{
        Preset = "Windows Desktop - Student"
        Output = Join-Path $BuildRoot "student\ClefiraStudent.exe"
    }
}

foreach ($target in $targets) {
    Invoke-WindowsExport -GodotExe $GodotExe -PresetName $target.Preset -OutputPath $target.Output
}

Write-Host "Windows desktop export complete."
