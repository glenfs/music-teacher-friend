param(
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$imageGen = Join-Path $env:USERPROFILE '.codex\skills\.system\imagegen\scripts\image_gen.py'
$prompts = Join-Path $PSScriptRoot 'prompts.jsonl'
$outDir = Join-Path $PSScriptRoot 'outputs'

if (-not (Test-Path $imageGen)) {
    throw "Image generation CLI not found: $imageGen"
}

if (-not (Test-Path $prompts)) {
    throw "Prompt batch not found: $prompts"
}

if (-not $DryRun -and -not $env:OPENAI_API_KEY) {
    throw "OPENAI_API_KEY is not set. Set it or run with -DryRun."
}

$args = @(
    $imageGen,
    'generate-batch',
    '--input', $prompts,
    '--out-dir', $outDir,
    '--concurrency', '3',
    '--quality', 'high',
    '--size', '1024x1024',
    '--downscale-max-dim', '512',
    '--downscale-suffix', '-512'
)

if ($DryRun) {
    $args += '--dry-run'
}

if ($Force) {
    $args += '--force'
}

Push-Location $repoRoot
try {
    python @args
}
finally {
    Pop-Location
}
