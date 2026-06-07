param(
    [switch]$Windowed,
    [switch]$Headless,
    [string]$Scope
)

$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectFile = Join-Path $repoRoot 'project.godot'

# Resolve the Godot binary:
#   1. $env:GODOT_BIN (CI / portable installs) — full path to the executable
#   2. Local developer path (Glen's machine)
# Prefer the console build when available so QA output gets piped back.
if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) {
    $godotConsole = $env:GODOT_BIN
} else {
    $godotDir = 'C:\ProgrammingLanguages\gadot\Godot_v4.6-stable_win64.exe'
    $godotConsole = Join-Path $godotDir 'Godot_v4.6-stable_win64_console.exe'
}

if (-not (Test-Path $godotConsole)) {
    Write-Error "Godot binary not found. Set `$env:GODOT_BIN to the executable path, or install Godot at $godotConsole"
}
if (-not (Test-Path $projectFile)) {
    Write-Error "Godot project file not found: $projectFile"
}

$args = @('--path', $repoRoot)

if ($Headless -or (-not $Windowed)) {
    $args = @('--headless') + $args
} else {
    $args = @('--display-driver', 'windows', '--rendering-driver', 'opengl3') + $args
}

$args += @('--', '--qa')
if ($Scope -and $Scope.Trim().Length -gt 0) {
    $args += @('--qa-scope', $Scope.Trim())
}

& $godotConsole @args
exit $LASTEXITCODE
