param(
    [int]$Minutes = 60,
    [switch]$Windowed,
    [switch]$Headless,
    [string]$Scope = "all"
)

$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectFile = Join-Path $repoRoot 'project.godot'
$logDir = Join-Path $env:APPDATA 'Godot\app_userdata\Clefira\qa_soak_logs'
$godotDir = 'C:\ProgrammingLanguages\gadot\Godot_v4.6-stable_win64.exe'
$godotConsole = Join-Path $godotDir 'Godot_v4.6-stable_win64_console.exe'

function ConvertTo-WindowsArgument {
    param([string]$Value)
    if ($null -eq $Value) {
        return '""'
    }
    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Add-SoakContent {
    param(
        [string]$Path,
        [string]$Value
    )
    for ($attempt = 1; $attempt -le 8; $attempt += 1) {
        try {
            Add-Content -Path $Path -Value $Value -ErrorAction Stop
            return
        } catch {
            if ($attempt -eq 8) {
                throw
            }
            Start-Sleep -Milliseconds 250
        }
    }
}

if (-not (Test-Path $godotConsole)) {
    Write-Error "Godot console binary not found: $godotConsole"
}
if (-not (Test-Path $projectFile)) {
    Write-Error "Godot project file not found: $projectFile"
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$startedStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$rawLog = Join-Path $logDir "qa_soak_${startedStamp}_raw.log"
$cycleCsv = Join-Path $logDir "qa_soak_${startedStamp}_cycles.csv"

$godotArgs = @('--path', $repoRoot)
if ($Headless -or (-not $Windowed)) {
    $godotArgs = @('--headless') + $godotArgs
} else {
    $godotArgs = @('--display-driver', 'windows', '--rendering-driver', 'opengl3') + $godotArgs
}

$godotArgs += @('--', '--qa')
if ($Scope -and $Scope.Trim().Length -gt 0 -and $Scope.Trim().ToLowerInvariant() -ne 'all') {
    $godotArgs += @('--qa-scope', $Scope.Trim())
}

"cycle,start,end,exit_code,elapsed_seconds,stdout_log,stderr_log" | Set-Content -Path $cycleCsv -Encoding UTF8
"QA soak started: $(Get-Date -Format o)" | Set-Content -Path $rawLog -Encoding UTF8
"Repo root: $repoRoot" | Add-Content -Path $rawLog
"Project file: $projectFile" | Add-Content -Path $rawLog
"Godot console: $godotConsole" | Add-Content -Path $rawLog
$argumentLine = ($godotArgs | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' '
"Arguments: $argumentLine" | Add-Content -Path $rawLog

$deadline = (Get-Date).AddMinutes([Math]::Max(1, $Minutes))
$cycle = 0

while ((Get-Date) -lt $deadline) {
    $cycle += 1
    $start = Get-Date
    $stdout = Join-Path $logDir ("qa_soak_{0}_cycle_{1:000}_stdout.log" -f $startedStamp, $cycle)
    $stderr = Join-Path $logDir ("qa_soak_{0}_cycle_{1:000}_stderr.log" -f $startedStamp, $cycle)

    Add-SoakContent -Path $rawLog -Value ""
    Add-SoakContent -Path $rawLog -Value "===== CYCLE $cycle START $($start.ToString('o')) ====="

    $commandLine = '"{0}" {1} > "{2}" 2> "{3}"' -f $godotConsole, $argumentLine, $stdout, $stderr
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Run through cmd.exe so Godot stderr goes directly to a file. This
        # avoids Windows PowerShell wrapping normal Godot warnings as
        # NativeCommandError while preserving the real process exit code.
        $ErrorActionPreference = 'Continue'
        & cmd.exe /d /s /c $commandLine
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $stdoutText = Get-Content -Path $stdout -Raw -ErrorAction SilentlyContinue
    $stderrText = Get-Content -Path $stderr -Raw -ErrorAction SilentlyContinue

    $end = Get-Date
    $elapsed = [Math]::Round(($end - $start).TotalSeconds, 1)
    if ($stdoutText) {
        Add-SoakContent -Path $rawLog -Value $stdoutText
    }
    if ($stderrText) {
        Add-SoakContent -Path $rawLog -Value "--- STDERR ---"
        Add-SoakContent -Path $rawLog -Value $stderrText
    }
    Add-SoakContent -Path $rawLog -Value "===== CYCLE $cycle END $($end.ToString('o')) EXIT $exitCode ELAPSED ${elapsed}s ====="
    Add-SoakContent -Path $cycleCsv -Value "$cycle,$($start.ToString('o')),$($end.ToString('o')),$exitCode,$elapsed,$stdout,$stderr"

    if ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
    }
}

Add-SoakContent -Path $rawLog -Value "QA soak finished: $(Get-Date -Format o)"
"Raw log: $rawLog"
"Cycle CSV: $cycleCsv"
exit 0
