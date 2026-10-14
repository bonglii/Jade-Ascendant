param([string]$AdbPath = '')
$ErrorActionPreference = 'Stop'
try {
    if (-not $AdbPath) {
        $found = Get-Command adb.exe -ErrorAction SilentlyContinue
        if ($found) { $AdbPath = $found.Source }
        else {
            $candidates = @('D:\Godot\tools\platform-tools\adb.exe', 'D:\Godot\tools\adb.exe')
            if ($env:ANDROID_HOME) { $candidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe' }
            foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate) { $AdbPath = $candidate; break } }
        }
    }
    if (-not $AdbPath -or -not (Test-Path -LiteralPath $AdbPath)) { throw 'ADB not found. Run with -AdbPath pointing to adb.exe.' }
    $device = @(& $AdbPath -d get-state 2>&1)
    if ($LASTEXITCODE -ne 0 -or ($device -join '') -notmatch '^device$') { throw 'Connect one USB Android phone and allow USB debugging.' }
    $package = @(& $AdbPath -d shell dumpsys package com.yungdevstudio.jadeascendant)
    if ($LASTEXITCODE -ne 0 -or ($package -join "`n") -notmatch 'versionCode=') { throw 'Jade Ascendant package not found.' }
    $logs = @(& $AdbPath -d logcat -d -v brief)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Android logcat.' }
    $relevant = @($logs | Where-Object { $_ -match 'godot' -and $_ -match 'JADE_ADS_QA|AdMobProvider|PoingGodotAdMob' } | Select-Object -Last 60)
    $report = @('JADE_REWARDED_AD_DIAGNOSTIC_V1', ('TIME=' + (Get-Date -Format o)))
    $report += @($package | Where-Object { $_ -match 'versionCode=|versionName=|android.permission.INTERNET:' })
    if ($relevant.Count -eq 0) { $report += 'NO_AD_TRACE: Re-export patched Android APK, open Pavilion and try the optional ad button.' }
    else { $report += $relevant }
    $report += 'NOTE: load_error_code=2 suggests network; 3 no fill; 1 request/config. Codes alone do not prove root cause.'
    $report += 'Debug Android uses a Google test unit. Desktop cannot display native Android ads.'
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $folder = Join-Path $root 'artifacts'
    [void](New-Item -ItemType Directory -Force -Path $folder)
    $path = Join-Path $folder 'Jade-Rewarded-Ad-Report.txt'
    [IO.File]::WriteAllLines($path, [string[]]$report, (New-Object Text.UTF8Encoding($false)))
    $report | ForEach-Object { Write-Host $_ }
    Write-Host ('REPORT_SAVED=' + $path)
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
