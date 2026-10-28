$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
foreach ($directory in @($taskRoot, (Join-Path $taskRoot 'frontend'), (Join-Path $taskRoot 'backend-gateway'), (Join-Path $taskRoot 'ml-service'))) {
    $target = Join-Path $directory '.env'
    $example = Join-Path $directory '.env.example'
    if (!(Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $example)) {
        Copy-Item -LiteralPath $example -Destination $target
    }
}
