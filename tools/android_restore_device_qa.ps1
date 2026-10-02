param(
    [ValidateSet('Audit','Build','Run','BuildRun')][string]$Action = 'Audit',
    [string]$GodotPath = '',
    [string]$DeviceSerial = '',
    [string]$ApkPath = '',
    [switch]$KeepApp
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Artifacts = Join-Path $ProjectRoot 'artifacts'
$LocalFolder = Join-Path $ProjectRoot '.local'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$QaToken = 'ANDROID_DESTRUCTIVE_QA_ONLY'
$QaScene = 'res://tests/android/android_restore_device_qa.tscn'
$QaBootstrap = 'AndroidRestoreDeviceBootstrapQA="*res://tests/android/android_restore_device_bootstrap_qa.gd"'
$QaStub = '*res://tests/android/android_restore_external_services_stub_qa.gd'
New-Item -ItemType Directory -Force $Artifacts,$LocalFolder | Out-Null

function Write-Utf8([string]$Path,[string]$Value) {
    [System.IO.File]::WriteAllText($Path,$Value,$Utf8)
}

function Get-HeadSha {
    $sha = (& git -C $ProjectRoot rev-parse HEAD 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[0-9a-f]{40}$') { throw 'Tidak dapat membaca git HEAD.' }
    return $sha
}

function Get-GodotExecutable {
    $candidate = $GodotPath.Trim().Trim('"')
    $cache = Join-Path $LocalFolder 'godot-path.txt'
    if (-not $candidate -and (Test-Path -LiteralPath $cache -PathType Leaf)) {
        $candidate = ([System.IO.File]::ReadAllText($cache)).Trim().Trim('"')
    }
    if (-not $candidate) {
        foreach ($name in @('Godot_v4.7.2-stable_win64_console.exe','godot4.exe','godot.exe')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
            if ($command) { $candidate = $command.Source; break }
        }
    }
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw 'Godot 4.7.2 tidak ditemukan. Beri -GodotPath atau jalankan PERIKSA_GAME lebih dulu agar .local/godot-path.txt tersedia.'
    }
    $version = (& $candidate --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2\.') {
        throw "Android restore QA dikunci ke Godot 4.7.2. Terbaca: $version"
    }
    return $candidate
}

function New-QaWorkspace([string]$HeadSha) {
    $name = 'jade_android_restore_qa_' + [guid]::NewGuid().ToString('N')
    $root = Join-Path ([System.IO.Path]::GetTempPath()) $name
    $archive = Join-Path ([System.IO.Path]::GetTempPath()) ($name + '.zip')
    New-Item -ItemType Directory -Force $root | Out-Null
    & git -C $ProjectRoot archive --format=zip --output=$archive $HeadSha
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        throw 'git archive HEAD gagal. QA device tidak pernah memakai working tree langsung.'
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $root -Force
    Remove-Item -LiteralPath $archive -Force
    return $root
}

function Replace-ExactlyOnce([string]$Text,[string]$Pattern,[string]$Replacement,[string]$Label) {
    $regex = [regex]::new($Pattern,[System.Text.RegularExpressions.RegexOptions]::Multiline)
    $matches = $regex.Matches($Text)
    if ($matches.Count -ne 1) { throw "$Label harus match tepat satu kali; terbaca $($matches.Count)." }
    return $regex.Replace($Text,$Replacement,1)
}

function Patch-QaWorkspace([string]$Workspace,[string]$HeadSha) {
    $projectPath = Join-Path $Workspace 'project.godot'
    $presetPath = Join-Path $Workspace 'export_presets.cfg'
    $restorePath = Join-Path $Workspace 'scripts/managers/cloud_registered_path_restore_qa.gd'
    foreach ($path in @($projectPath,$presetPath,$restorePath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "QA archive tidak lengkap: $path" }
    }

    $project = [System.IO.File]::ReadAllText($projectPath)
    if ($project -notmatch 'run/main_scene="res://scenes/system/boot\.tscn"') { throw 'Production main scene anchor berubah.' }
    $project = $project.Replace('run/main_scene="res://scenes/system/boot.tscn"','run/main_scene="'+$QaScene+'"')
    $saveAnchor = 'SaveManager="*res://scripts/managers/save_manager.gd"'
    if (-not $project.Contains($saveAnchor)) { throw 'SaveManager autoload anchor hilang.' }
    if ($project.Contains('AndroidRestoreDeviceBootstrapQA=')) { throw 'Android QA bootstrap tidak boleh tracked sebagai production autoload.' }
    $project = $project.Replace($saveAnchor,$saveAnchor+"`n"+$QaBootstrap)
    foreach ($name in @('MonetizationManager','GoogleAccountManager','Firebase')) {
        $pattern = '(?m)^'+[regex]::Escape($name)+'=.*$'
        $replacement = $name+'="'+$QaStub+'"'
        $project = Replace-ExactlyOnce $project $pattern $replacement ("QA stub redirect " + $name)
    }
    $project = Replace-ExactlyOnce $project '(?m)^enabled=PackedStringArray\([^\r\n]*\)$' 'enabled=PackedStringArray()' 'editor plugin disable'
    $project = Replace-ExactlyOnce $project '(?m)^config/name="jade-ascendant"$' 'config/name="jade-ascendant-restore-qa"' 'QA application name'
    if ($project -match '(?m)^\[jade_android_restore_qa\]$') { throw 'QA project settings unexpectedly tracked.' }
    $project += "`n[jade_android_restore_qa]`nenabled=true`ntoken=`"$QaToken`"`nhead_sha=`"$HeadSha`"`n"
    Write-Utf8 $projectPath $project

    $restore = [System.IO.File]::ReadAllText($restorePath)
    $qaPattern = '(?ms)^func _qa_enabled\(\) -> bool:\r?\n\treturn \(\r?\n\t\tOS\.has_feature\("editor"\)\r?\n\t\tand OS\.get_environment\("JADE_GATE9_TEST_ONLY"\) == "1"\r?\n\t\tand OS\.get_environment\("JADE_REGISTERED_RESTORE_TEST_ONLY"\) == "1"\r?\n\t\tand OS\.get_environment\("JADE_REGISTERED_RESTORE_ACK"\) == REQUIRED_ACK\r?\n\t\)'
    $qaReplacement = @'
func _qa_enabled() -> bool:
	if OS.has_feature("editor"):
		return (
			OS.get_environment("JADE_GATE9_TEST_ONLY") == "1"
			and OS.get_environment("JADE_REGISTERED_RESTORE_TEST_ONLY") == "1"
			and OS.get_environment("JADE_REGISTERED_RESTORE_ACK") == REQUIRED_ACK
		)
	return (
		OS.has_feature("android")
		and OS.is_debug_build()
		and bool(ProjectSettings.get_setting("jade_android_restore_qa/enabled", false))
		and str(ProjectSettings.get_setting("jade_android_restore_qa/token", "")) == "ANDROID_DESTRUCTIVE_QA_ONLY"
	)
'@
    $restore = Replace-ExactlyOnce $restore $qaPattern $qaReplacement 'disposable Android QA activation patch'
    Write-Utf8 $restorePath $restore

    $preset = [System.IO.File]::ReadAllText($presetPath)
    $packageMatch = [regex]::Match($preset,'(?m)^package/unique_name="(?<id>[a-zA-Z0-9_.]+)"$')
    if (-not $packageMatch.Success) { throw 'Android package id tidak ditemukan.' }
    $productionPackage = $packageMatch.Groups['id'].Value
    if ($productionPackage.EndsWith('.restoreqa')) { throw 'Production package id sudah memakai suffix QA.' }
    $qaPackage = $productionPackage + '.restoreqa'
    $preset = $preset.Replace($packageMatch.Value,'package/unique_name="'+$qaPackage+'"')
    $preset = Replace-ExactlyOnce $preset '(?m)^package/name="[^"]*"$' 'package/name="Jade Ascendant Restore QA"' 'QA package name'
    $preset = Replace-ExactlyOnce $preset '(?m)^gradle_build/export_format=1$' 'gradle_build/export_format=0' 'QA APK export format'
    $preset = Replace-ExactlyOnce $preset '(?m)^export_path="[^"]*"$' 'export_path="artifacts/JadeAscendant-RestoreQA.apk"' 'QA export path'
    $preset = Replace-ExactlyOnce $preset '(?m)^package/show_as_launcher_app=false$' 'package/show_as_launcher_app=true' 'QA launcher visibility'
    $excludeLine = [regex]::Match($preset,'(?m)^exclude_filter="(?<value>[^"]*)"$')
    if (-not $excludeLine.Success -or $excludeLine.Groups['value'].Value -notmatch '(^|,)tests/\*(,|$)') {
        throw 'Production export must exclude tests/* before the disposable QA transform.'
    }
    $excludeValue = $excludeLine.Groups['value'].Value
    $items = @($excludeValue.Split(',') | Where-Object { $_ -ne 'tests/*' })
    $preset = $preset.Replace($excludeLine.Value,'exclude_filter="'+($items -join ',')+'"')
    Write-Utf8 $presetPath $preset

    return [ordered]@{ workspace=$Workspace; head_sha=$HeadSha; production_package=$productionPackage; qa_package=$qaPackage }
}

function Assert-QaWorkspace($Info) {
    $workspace = [string]$Info.workspace
    $project = [System.IO.File]::ReadAllText((Join-Path $workspace 'project.godot'))
    $preset = [System.IO.File]::ReadAllText((Join-Path $workspace 'export_presets.cfg'))
    $restore = [System.IO.File]::ReadAllText((Join-Path $workspace 'scripts/managers/cloud_registered_path_restore_qa.gd'))
    $saveIndex = $project.IndexOf('SaveManager="*res://scripts/managers/save_manager.gd"')
    $bootIndex = $project.IndexOf($QaBootstrap)
    $progressIndex = $project.IndexOf('ProgressionManager="*res://scripts/game/ProgressionManager.gd"')
    if (-not ($saveIndex -ge 0 -and $saveIndex -lt $bootIndex -and $bootIndex -lt $progressIndex)) { throw 'QA bootstrap ordering bukan SaveManager -> bootstrap -> permanent managers.' }
    if ($project -notmatch [regex]::Escape('run/main_scene="'+$QaScene+'"')) { throw 'QA main scene tidak aktif di workspace.' }
    if ($project -notmatch '(?m)^enabled=PackedStringArray\(\)$') { throw 'Native editor/export plugins belum dinonaktifkan di workspace QA.' }
    foreach ($name in @('MonetizationManager','GoogleAccountManager','Firebase')) {
        if ($project -notmatch ('(?m)^'+$name+'="\*res://tests/android/android_restore_external_services_stub_qa\.gd"$')) { throw "$name belum diarahkan ke offline QA stub." }
    }
    if ($restore -notmatch 'OS\.has_feature\("android"\)[\s\S]*OS\.is_debug_build\(\)[\s\S]*ANDROID_DESTRUCTIVE_QA_ONLY') { throw 'Disposable restore implementation belum di-arm khusus Android debug.' }
    if ($preset -notmatch ('(?m)^package/unique_name="'+[regex]::Escape([string]$Info.qa_package)+'"$')) { throw 'QA package id tidak terisolasi.' }
    if ($preset -notmatch '(?m)^gradle_build/export_format=0$') { throw 'QA build harus APK.' }
    $exclude = [regex]::Match($preset,'(?m)^exclude_filter="(?<value>[^"]*)"$')
    if (-not $exclude.Success -or $exclude.Groups['value'].Value -match '(^|,)tests/\*(,|$)') { throw 'tests/android harus masuk hanya ke disposable QA APK.' }
    if ($preset -match 'firebase deploy|service.account|firebase login') { throw 'QA preset berisi deployment primitive.' }
}

function New-AuditReport($Info,[string]$Status) {
    return [ordered]@{
        status=$Status
        head_sha=$Info.head_sha
        production_package=$Info.production_package
        qa_package=$Info.qa_package
        source='git archive HEAD'
        production_worktree_mutated=$false
        firebase=$false
        google_sign_in=$false
        monetization=$false
        cloud_transfer=$false
        device_status='NOT_RUN'
    }
}

function Invoke-Audit {
    $head = Get-HeadSha
    $projectHash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'project.godot') -Algorithm SHA256).Hash
    $presetHash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'export_presets.cfg') -Algorithm SHA256).Hash
    $restoreHash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'scripts/managers/cloud_registered_path_restore_qa.gd') -Algorithm SHA256).Hash
    $workspace = $null
    try {
        $workspace = New-QaWorkspace $head
        $info = Patch-QaWorkspace $workspace $head
        Assert-QaWorkspace $info
        if ((Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'project.godot') -Algorithm SHA256).Hash -ne $projectHash) { throw 'Audit mutated tracked project.godot.' }
        if ((Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'export_presets.cfg') -Algorithm SHA256).Hash -ne $presetHash) { throw 'Audit mutated tracked export_presets.cfg.' }
        if ((Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'scripts/managers/cloud_registered_path_restore_qa.gd') -Algorithm SHA256).Hash -ne $restoreHash) { throw 'Audit mutated locked restore engine.' }
        $report = New-AuditReport $info 'PASS'
        Write-Utf8 (Join-Path $Artifacts 'android-restore-device-qa-audit.json') ($report | ConvertTo-Json -Depth 6)
        Write-Host 'ANDROID_RESTORE_DEVICE_AUDIT_PASS' -ForegroundColor Green
        return $report
    }
    finally {
        if ($workspace -and (Test-Path -LiteralPath $workspace -PathType Container)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
    }
}

function Invoke-Build {
    $head = Get-HeadSha
    $godot = Get-GodotExecutable
    $workspace = $null
    try {
        $workspace = New-QaWorkspace $head
        $info = Patch-QaWorkspace $workspace $head
        Assert-QaWorkspace $info
        & $godot --headless --path $workspace --import 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Godot import QA workspace gagal.' }
        & $godot --headless --path $workspace --install-android-build-template 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Pemasangan Android build template di workspace QA gagal.' }
        $short = $head.Substring(0,7)
        $apk = Join-Path $Artifacts ("JadeAscendant-RestoreQA-$short.apk")
        & $godot --headless --path $workspace --export-debug Android $apk 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $apk -PathType Leaf) -or (Get-Item -LiteralPath $apk).Length -le 0) {
            throw 'Export debug APK gagal. Pastikan Godot 4.7.2 export templates dan Android SDK terpasang.'
        }
        $report = New-AuditReport $info 'PASS'
        $report.apk = $apk
        $report.apk_sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-Utf8 (Join-Path $Artifacts 'android-restore-device-qa-build.json') ($report | ConvertTo-Json -Depth 6)
        Write-Host "ANDROID_RESTORE_DEVICE_BUILD_PASS | $apk" -ForegroundColor Green
        return [ordered]@{ apk=$apk; qa_package=$info.qa_package; head_sha=$head }
    }
    finally {
        if ($workspace -and (Test-Path -LiteralPath $workspace -PathType Container)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
    }
}

function Get-Adb {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($root in @($env:ANDROID_HOME,$env:ANDROID_SDK_ROOT)) {
        if ($root) { $candidates.Add((Join-Path $root 'platform-tools\adb.exe')) | Out-Null }
    }
    if ($env:LOCALAPPDATA) { $candidates.Add((Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')) | Out-Null }
    $command = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates.Add($command.Source) | Out-Null }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    throw 'adb.exe tidak ditemukan. Pasang Android SDK Platform Tools.'
}

function Get-AdbPrefix([string]$Adb) {
    if ($DeviceSerial) { return @('-s',$DeviceSerial) }
    $lines = & $Adb devices
    if ($LASTEXITCODE -ne 0) { throw 'adb devices gagal.' }
    $devices = @($lines | Where-Object { $_ -match '^(?<serial>\S+)\s+device$' } | ForEach-Object { ([regex]::Match($_,'^(?<serial>\S+)')).Groups['serial'].Value })
    if ($devices.Count -ne 1) { throw "Hubungkan tepat satu device Android atau beri -DeviceSerial. Device siap: $($devices.Count)" }
    return @('-s',$devices[0])
}

function Invoke-Adb([string]$Adb,[string[]]$Prefix,[string[]]$Arguments,[bool]$IgnoreFailure=$false) {
    & $Adb @Prefix @Arguments
    $code = $LASTEXITCODE
    if (-not $IgnoreFailure -and $code -ne 0) { throw ('adb gagal: ' + ($Arguments -join ' ')) }
    return $code
}

function Start-QaApp([string]$Adb,[string[]]$Prefix,[string]$Package) {
    $null = Invoke-Adb $Adb $Prefix @('shell','monkey','-p',$Package,'-c','android.intent.category.LAUNCHER','1') $false
}

function Save-DeviceLog([string]$Adb,[string[]]$Prefix,[string]$Path) {
    $log = (& $Adb @Prefix logcat -d -v threadtime 2>&1 | Out-String)
    Write-Utf8 $Path $log
    return $log
}

function Invoke-Run([string]$InputApk,[string]$Package,[string]$HeadSha) {
    $adb = Get-Adb
    $prefix = Get-AdbPrefix $adb
    $serial = $prefix[1]
    if (-not (Test-Path -LiteralPath $InputApk -PathType Leaf)) { throw "APK QA tidak ditemukan: $InputApk" }
    $null = Invoke-Adb $adb $prefix @('uninstall',$Package) $true
    $null = Invoke-Adb $adb $prefix @('install','-r',$InputApk) $false
    $null = Invoke-Adb $adb $prefix @('logcat','-c') $false
    Start-QaApp $adb $prefix $Package

    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $markers = New-Object System.Collections.Generic.List[string]
    $deadline = (Get-Date).AddMinutes(10)
    $logPath = Join-Path $Artifacts 'android-restore-device-qa.log'
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 450
        $raw = (& $adb @prefix logcat -d -v raw 2>&1 | Out-String)
        $lines = @($raw -split "`r?`n" | Where-Object { $_ -match 'JADE_ANDROID_RESTORE_' })
        foreach ($line in $lines) {
            $clean = $line.Trim()
            if (-not $clean -or -not $seen.Add($clean)) { continue }
            $markers.Add($clean) | Out-Null
            Write-Host $clean -ForegroundColor Cyan
            if ($clean -match 'JADE_ANDROID_RESTORE_DEVICE_FAIL') {
                $null = Save-DeviceLog $adb $prefix $logPath
                $summary = [ordered]@{ status='FAIL'; head_sha=$HeadSha; package=$Package; device=$serial; apk=$InputApk; markers=$markers }
                Write-Utf8 (Join-Path $Artifacts 'android-restore-device-qa-summary.json') ($summary | ConvertTo-Json -Depth 8)
                throw 'Android destructive restore QA melaporkan FAIL. Baca artifacts/android-restore-device-qa.log.'
            }
            if ($clean -match 'JADE_ANDROID_RESTORE_FORCE_STOP') {
                $null = Invoke-Adb $adb $prefix @('shell','am','force-stop',$Package) $false
                Start-Sleep -Milliseconds 550
                Start-QaApp $adb $prefix $Package
                continue
            }
            if ($clean -match 'JADE_ANDROID_RESTORE_DEVICE_PASS') {
                $null = Save-DeviceLog $adb $prefix $logPath
                $summary = [ordered]@{
                    status='PASS'; head_sha=$HeadSha; package=$Package; device=$serial; apk=$InputApk
                    apk_sha256=(Get-FileHash -LiteralPath $InputApk -Algorithm SHA256).Hash.ToLowerInvariant()
                    markers=$markers
                }
                Write-Utf8 (Join-Path $Artifacts 'android-restore-device-qa-summary.json') ($summary | ConvertTo-Json -Depth 8)
                if (-not $KeepApp) { $null = Invoke-Adb $adb $prefix @('uninstall',$Package) $true }
                Write-Host 'ANDROID_RESTORE_DEVICE_QA_PASS' -ForegroundColor Green
                return $summary
            }
        }
    }
    $null = Save-DeviceLog $adb $prefix $logPath
    throw 'Android destructive restore QA timeout. Baca artifacts/android-restore-device-qa.log.'
}

function Find-LatestQaApk {
    if ($ApkPath) { return (Resolve-Path -LiteralPath $ApkPath).Path }
    $latest = Get-ChildItem -LiteralPath $Artifacts -Filter 'JadeAscendant-RestoreQA-*.apk' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { throw 'Belum ada QA APK. Jalankan -Action Build atau BuildRun.' }
    return $latest.FullName
}

try {
    Set-Location -LiteralPath $ProjectRoot
    switch ($Action) {
        'Audit' { $null = Invoke-Audit }
        'Build' { $null = Invoke-Build }
        'Run' {
            $head = Get-HeadSha
            $audit = Invoke-Audit
            $apk = Find-LatestQaApk
            $null = Invoke-Run $apk ([string]$audit.qa_package) $head
        }
        'BuildRun' {
            $build = Invoke-Build
            $null = Invoke-Run ([string]$build.apk) ([string]$build.qa_package) ([string]$build.head_sha)
        }
    }
    exit 0
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
