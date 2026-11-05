param([string]$DeviceId)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
$emulatorExe = Join-Path $env:LOCALAPPDATA 'Android/sdk/emulator/emulator.exe'

if (-not (Test-Path -LiteralPath $adb)) {
    throw 'Android adb was not found in the default SDK location.'
}

function Get-OnlineDevices {
    @(& $adb devices | Where-Object { $_ -match '^\S+\s+device\s*$' } | ForEach-Object { ($_ -split '\s+')[0] })
}

if (-not $DeviceId) {
    $devices = Get-OnlineDevices
    if ($devices.Count -eq 0) {
        Write-Host "No active Android device found. Starting Virtual Android Phone (Emulator)..." -ForegroundColor Cyan
        
        $avdName = $null
        if (Test-Path -LiteralPath $emulatorExe) {
            $avds = @(& $emulatorExe -list-avds)
            if ($avds.Count -gt 0) {
                $avdName = $avds[0]
            }
        }
        
        if ($avdName) {
            Write-Host "Launching AVD: $avdName..." -ForegroundColor Green
            Start-Process -FilePath $emulatorExe -ArgumentList "-avd", $avdName
        } else {
            Write-Host "Launching default emulator via flutter..." -ForegroundColor Green
            Start-Process -FilePath "flutter" -ArgumentList "emulators", "--launch", "Medium_Phone_API_37.0"
        }

        Write-Host "Waiting for Android Virtual Device to boot up..." -ForegroundColor Yellow
        & $adb wait-for-device
        
        # Wait until boot completed
        $maxWaitSeconds = 90
        $waited = 0
        while ($waited -lt $maxWaitSeconds) {
            $boot = & $adb shell getprop sys.boot_completed 2>$null
            if ($boot -match '1') {
                break
            }
            Start-Sleep -Seconds 2
            $waited += 2
        }

        $devices = Get-OnlineDevices
        if ($devices.Count -eq 0) {
            throw 'Timed out waiting for Android emulator to become ready.'
        }
    }
    
    $DeviceId = $devices[0]
}

Write-Host "Connected to Android device: $DeviceId" -ForegroundColor Green

# Forwarding is lost when the phone reconnects; restore it on all connected devices.
$allOnline = Get-OnlineDevices
foreach ($d in $allOnline) {
    & $adb -s $d reverse tcp:5001 tcp:5001 2>$null
    & $adb -s $d reverse tcp:5000 tcp:5000 2>$null
}
Write-Host "Set up port forwarding (tcp:5001) for: $($allOnline -join ', ')" -ForegroundColor Green

Push-Location $PSScriptRoot
try {
    Write-Host "Launching Flutter app on $DeviceId..." -ForegroundColor Cyan
    flutter run -d $DeviceId
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode
