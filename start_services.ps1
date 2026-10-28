param(
    [switch]$Setup,
    [switch]$Lan,
    [int]$MlPort,
    [int]$GatewayPort
)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
& (Join-Path $projectRoot 'scripts/setup_env.ps1')
$mlRoot = Join-Path $projectRoot 'ml-service'
$gatewayRoot = Join-Path $projectRoot 'backend-gateway'
$pythonExe = Join-Path $mlRoot '.venv/Scripts/python.exe'
$gatewayExe = Join-Path $gatewayRoot 'gateway.exe'
$logs = Join-Path $projectRoot '.logs'
$mlProcess = $null
$gatewayProcess = $null
$previousMlUrl = $env:ML_SERVICE_URL
$previousGatewayAddr = $env:GATEWAY_ADDR
function Read-DotEnv([string[]]$Paths) {
    $settings = @{}
    foreach ($path in $Paths) {
        if (!(Test-Path -LiteralPath $path)) {
            if (Test-Path -LiteralPath "$path.example") { Copy-Item -LiteralPath "$path.example" -Destination $path }
        }
        if (Test-Path -LiteralPath $path) {
            foreach ($line in Get-Content -LiteralPath $path) {
                if ($line -match '^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
                    $key = $Matches[1]
                    $value = $Matches[2]
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    } else { $value = ($value -replace '\s+#.*$', '').Trim() }
                    $settings[$key] = $value
                }
            }
        }
    }
    return $settings
}
function Get-Setting($Settings, [string]$Key, [string]$Fallback) {
    $processValue = [Environment]::GetEnvironmentVariable($Key, 'Process')
    if ($null -ne $processValue) { return $processValue }
    if ($Settings.ContainsKey($Key)) { return $Settings[$Key] }
    return $Fallback
}
$mlSettings = Read-DotEnv @((Join-Path $projectRoot '.env'), (Join-Path $mlRoot '.env'))
$ginSettings = Read-DotEnv @((Join-Path $projectRoot '.env'), (Join-Path $gatewayRoot '.env'))
$configuredAddress = Get-Setting $ginSettings 'GATEWAY_ADDR' '127.0.0.1:8080'
if (!$PSBoundParameters.ContainsKey('MlPort')) { $MlPort = [int](Get-Setting $mlSettings 'ML_PORT' '8000') }
if (!$PSBoundParameters.ContainsKey('GatewayPort')) { $GatewayPort = ([Uri]"http://$configuredAddress").Port }
$mlHost = Get-Setting $mlSettings 'ML_HOST' '127.0.0.1'
$mlHealthHost = if ($mlHost -eq '0.0.0.0') { '127.0.0.1' } else { $mlHost }
function Assert-ExitCode([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed (exit $LASTEXITCODE)." }
}
function Wait-Ready([string]$Url, $Process) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $Process.Refresh()
        if ($Process.HasExited) { throw "Service exited. Inspect $logs." }
        try {
            $response = Invoke-RestMethod -Uri $Url -TimeoutSec 1
            if ($response.status -eq 'ok') { return }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    throw "Service did not become ready: $Url. Inspect $logs."
}
try {
    foreach ($port in @($MlPort, $GatewayPort)) {
        if ($port -lt 1024 -or $port -gt 65535) { throw 'Ports must be between 1024 and 65535.' }
        $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($listener) { throw "Port $port is already in use. Choose -MlPort and -GatewayPort." }
    }
    if ($MlPort -eq $GatewayPort) { throw 'Choose different ML and gateway ports.' }
    if ($Setup -or !(Test-Path -LiteralPath $pythonExe)) {
        if (!(Test-Path -LiteralPath $pythonExe)) {
            python -m venv (Join-Path $mlRoot '.venv')
            Assert-ExitCode 'Create Python environment'
        }
        & $pythonExe -m pip install -r (Join-Path $mlRoot 'requirements.txt')
        Assert-ExitCode 'Install Python dependencies'
    }
    Push-Location $mlRoot
    try {
        if ($Setup -or !(Test-Path -LiteralPath 'saved_models/bundle.joblib')) {
            & $pythonExe download_datasets.py
            Assert-ExitCode 'Download and verify UCI datasets'
            & $pythonExe train.py
            Assert-ExitCode 'Model training'
        }
    } finally { Pop-Location }
    Push-Location $gatewayRoot
    try {
        go build -o gateway.exe .
        Assert-ExitCode 'Build Gin gateway'
    } finally { Pop-Location }
    New-Item -ItemType Directory -Force -Path $logs | Out-Null
    $mlProcess = Start-Process -FilePath $pythonExe -ArgumentList '-m','uvicorn','app.main:app','--host',$mlHost,'--port',"$MlPort" -WorkingDirectory $mlRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'ml.out.log') -RedirectStandardError (Join-Path $logs 'ml.err.log')
    Wait-Ready "http://${mlHealthHost}:$MlPort/health" $mlProcess
    # The launcher owns both processes, so its actual ML port must win over static .env values.
    $env:ML_SERVICE_URL = "http://${mlHealthHost}:$MlPort"
    $bindAddress = if ($Lan) { '0.0.0.0' } else { ([Uri]"http://$configuredAddress").Host }
    $env:GATEWAY_ADDR = "${bindAddress}:$GatewayPort"
    $gatewayProcess = Start-Process -FilePath $gatewayExe -WorkingDirectory $gatewayRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'gin.out.log') -RedirectStandardError (Join-Path $logs 'gin.err.log')
    $ginHealthHost = if ($bindAddress -eq '0.0.0.0') { '127.0.0.1' } else { $bindAddress }
    Wait-Ready "http://${ginHealthHost}:$GatewayPort/health" $gatewayProcess
    Write-Host "CellScope is ready. Gin: http://127.0.0.1:$GatewayPort | FastAPI docs: http://127.0.0.1:$MlPort/docs"
    Write-Host "Android emulator API: http://10.0.2.2:$GatewayPort"
    Read-Host 'Press Enter to stop both services' | Out-Null
} finally {
    foreach ($process in @($gatewayProcess, $mlProcess)) {
        if ($null -ne $process) {
            $process.Refresh()
            if (!$process.HasExited) {
                # Include the base interpreter spawned by a Windows venv launcher.
                & taskkill /PID $process.Id /T /F 2>$null | Out-Null
            }
        }
    }
    $env:ML_SERVICE_URL = $previousMlUrl
    $env:GATEWAY_ADDR = $previousGatewayAddr
}
