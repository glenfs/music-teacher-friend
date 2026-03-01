param(
    [switch]$Windowed,
    [switch]$Headless,
    [string]$Scope
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotDir = 'C:\ProgrammingLanguages\gadot\Godot_v4.6-stable_win64.exe'
$godotConsole = Join-Path $godotDir 'Godot_v4.6-stable_win64_console.exe'

if (-not (Test-Path $godotConsole)) {
    Write-Error "Godot console binary not found: $godotConsole"
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
