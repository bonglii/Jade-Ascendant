param(
    [ValidateSet('Audit','Build','Run','BuildRun')][string]$Action = 'Audit',
    [string]$GodotPath = '',
    [string]$DeviceSerial = '',
    [string]$BridgeAarPath = '',
    [string]$ExpectedBridgeAarSha256 = '',
    [string]$ApkPath = '',
    [switch]$KeepApp
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Artifacts = Join-Path $ProjectRoot 'artifacts'
$LocalFolder = Join-Path $ProjectRoot '.local'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$QaFeature = 'jade_android_account_bound_transport_qa'
$QaHeadPlaceholder = 'QA_HEAD_SHA_PLACEHOLDER'
$QaScene = 'res://tests/android/android_account_bound_transport_device_qa.tscn'
$QaStub = '*res://tests/android/android_account_bound_transport_external_services_stub_qa.gd'
$QaPlugin = 'res://addons/JadeCloudNativeBridge/plugin.cfg'
$QaAarRelative = 'addons/JadeCloudNativeBridge/bin/debug/JadeCloudNativeBridge-debug.aar'
New-Item -ItemType Directory -Force $Artifacts,$LocalFolder | Out-Null

function Write-Utf8([string]$Path,[string]$Value) {
    [System.IO.File]::WriteAllText($Path,$Value,$Utf8)
}

function Invoke-NativeCaptured([string]$FilePath,[string[]]$Arguments,[string]$Label) {
    $token = [guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("jade_native_" + $token + ".stdout.txt")
    $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("jade_native_" + $token + ".stderr.txt")
    $previousPreference = $ErrorActionPreference
    $nativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    $previousNativePreference = $null
    $exitCode = -1
    try {
        if ($null -ne $nativePreference) {
            $previousNativePreference = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }
        $ErrorActionPreference = 'Continue'
        & $FilePath @Arguments 1> $stdoutPath 2> $stderrPath
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
        if ($null -ne $nativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($stdoutPath,$stderrPath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $value = [System.IO.File]::ReadAllText($path)
            if ($value) { $parts.Add($value.TrimEnd()) | Out-Null }
        }
    }
    Remove-Item -LiteralPath $stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
    return [ordered]@{ label=$Label; exit_code=[int]$exitCode; output=($parts -join [Environment]::NewLine) }
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
        throw 'Godot 4.7.2 tidak ditemukan. Beri -GodotPath atau pastikan .local/godot-path.txt tersedia.'
    }
    $version = (& $candidate --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2\.') {
        throw "Android transport QA dikunci ke Godot 4.7.2. Terbaca: $version"
    }
    return $candidate
}

function New-QaWorkspace([string]$HeadSha) {
    $name = 'jade_android_account_bound_transport_qa_' + [guid]::NewGuid().ToString('N')
    $root = Join-Path ([System.IO.Path]::GetTempPath()) $name
    $archive = Join-Path ([System.IO.Path]::GetTempPath()) ($name + '.zip')
    New-Item -ItemType Directory -Force $root | Out-Null
    & git -C $ProjectRoot archive --format=zip --output=$archive $HeadSha
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        throw 'git archive HEAD gagal. QA device tidak memakai working tree langsung.'
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $root -Force
    Remove-Item -LiteralPath $archive -Force
    return $root
}

function Replace-ExactlyOnce([string]$Text,[string]$Pattern,[string]$Replacement,[string]$Label) {
    $regex = [regex]::new($Pattern,[System.Text.RegularExpressions.RegexOptions]::Multiline)
    $matchList = $regex.Matches($Text)
    if ($matchList.Count -ne 1) { throw "$Label harus match tepat satu kali; terbaca $($matchList.Count)." }
    return $regex.Replace($Text,$Replacement,1)
}

function Patch-QaWorkspace([string]$Workspace,[string]$HeadSha) {
    $projectPath = Join-Path $Workspace 'project.godot'
    $presetPath = Join-Path $Workspace 'export_presets.cfg'
    $runnerPath = Join-Path $Workspace 'tests/android/android_account_bound_transport_device_qa.gd'
    foreach ($path in @($projectPath,$presetPath,$runnerPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "QA archive tidak lengkap: $path" }
    }

    $project = [System.IO.File]::ReadAllText($projectPath)
    if ($project -notmatch 'run/main_scene="res://scenes/system/boot\.tscn"') { throw 'Production main scene anchor berubah.' }
    $project = $project.Replace('run/main_scene="res://scenes/system/boot.tscn"','run/main_scene="'+$QaScene+'"')
    foreach ($name in @('MonetizationManager','GoogleAccountManager','Firebase')) {
        $pattern = '(?m)^'+[regex]::Escape($name)+'=.*$'
        $replacement = $name+'="'+$QaStub+'"'
        $project = Replace-ExactlyOnce $project $pattern $replacement ("QA stub redirect " + $name)
    }
    $project = Replace-ExactlyOnce $project '(?m)^enabled=PackedStringArray\([^\r\n]*\)$' ('enabled=PackedStringArray("'+$QaPlugin+'")') 'editor plugin isolation'
    $project = Replace-ExactlyOnce $project '(?m)^config/name="jade-ascendant"$' 'config/name="jade-ascendant-account-bound-transport-qa"' 'QA application name'
    if ($project -match [regex]::Escape($QaFeature)) { throw 'QA arming feature tidak boleh tracked di production project.godot.' }
    Write-Utf8 $projectPath $project

    $runner = [System.IO.File]::ReadAllText($runnerPath)
    $headLine = 'const EXPECTED_HEAD_SHA: String = "'+$QaHeadPlaceholder+'"'
    if ($runner.IndexOf($headLine) -lt 0 -or $runner.IndexOf($headLine) -ne $runner.LastIndexOf($headLine)) {
        throw 'Android account-bound runner HEAD placeholder harus ada tepat satu.'
    }
    $runner = $runner.Replace($headLine,'const EXPECTED_HEAD_SHA: String = "'+$HeadSha+'"')
    Write-Utf8 $runnerPath $runner

    $preset = [System.IO.File]::ReadAllText($presetPath)
    $packageMatch = [regex]::Match($preset,'(?m)^package/unique_name="(?<id>[a-zA-Z0-9_.]+)"$')
    if (-not $packageMatch.Success) { throw 'Android package id tidak ditemukan.' }
    $productionPackage = $packageMatch.Groups['id'].Value
    if ($productionPackage.EndsWith('.transportqa')) { throw 'Production package id sudah memakai suffix QA.' }
    $qaPackage = $productionPackage + '.transportqa'
    $preset = $preset.Replace($packageMatch.Value,'package/unique_name="'+$qaPackage+'"')
    $preset = Replace-ExactlyOnce $preset '(?m)^custom_features=""$' ('custom_features="'+$QaFeature+'"') 'QA custom export feature'
    $preset = Replace-ExactlyOnce $preset '(?m)^package/name="[^"]*"$' 'package/name="Jade Ascendant Transport QA"' 'QA package name'
    $preset = Replace-ExactlyOnce $preset '(?m)^gradle_build/export_format=1$' 'gradle_build/export_format=0' 'QA APK export format'
    $preset = Replace-ExactlyOnce $preset '(?m)^export_path="[^"]*"$' 'export_path="artifacts/JadeAscendant-AccountBoundTransportQA.apk"' 'QA export path'
    $preset = Replace-ExactlyOnce $preset '(?m)^package/show_as_launcher_app=false$' 'package/show_as_launcher_app=true' 'QA launcher visibility'
    $excludeLine = [regex]::Match($preset,'(?m)^exclude_filter="(?<value>[^"]*)"$')
    if (-not $excludeLine.Success -or $excludeLine.Groups['value'].Value -notmatch '(^|,)tests/\*(,|$)') {
        throw 'Production export harus exclude tests/* sebelum transform QA.'
    }
    $items = @($excludeLine.Groups['value'].Value.Split(',') | Where-Object { $_ -ne 'tests/*' })
    $preset = $preset.Replace($excludeLine.Value,'exclude_filter="'+($items -join ',')+'"')
    Write-Utf8 $presetPath $preset

    return [ordered]@{ workspace=$Workspace; head_sha=$HeadSha; production_package=$productionPackage; qa_package=$qaPackage }
}

function Assert-QaWorkspace($Info) {
    $workspace = [string]$Info.workspace
    $project = [System.IO.File]::ReadAllText((Join-Path $workspace 'project.godot'))
    $preset = [System.IO.File]::ReadAllText((Join-Path $workspace 'export_presets.cfg'))
    $runner = [System.IO.File]::ReadAllText((Join-Path $workspace 'tests/android/android_account_bound_transport_device_qa.gd'))
    if ($project -notmatch [regex]::Escape('run/main_scene="'+$QaScene+'"')) { throw 'QA main scene tidak aktif.' }
    if ($project -notmatch ('(?m)^enabled=PackedStringArray\("'+[regex]::Escape($QaPlugin)+'"\)$')) { throw 'Hanya JadeCloudNativeBridge yang boleh aktif sebagai export plugin QA.' }
    foreach ($name in @('MonetizationManager','GoogleAccountManager','Firebase')) {
        if ($project -notmatch ('(?m)^'+$name+'="\*res://tests/android/android_account_bound_transport_external_services_stub_qa\.gd"$')) {
            throw "$name belum diarahkan ke offline QA stub."
        }
    }
    if ($project -match [regex]::Escape($QaFeature)) { throw 'Disposable project.godot tidak boleh menjadi arming authority.' }
    $expectedHeadLine = 'const EXPECTED_HEAD_SHA: String = "'+[string]$Info.head_sha+'"'
    if ($runner.IndexOf($expectedHeadLine) -lt 0 -or $runner.IndexOf($expectedHeadLine) -ne $runner.LastIndexOf($expectedHeadLine)) {
        throw 'QA runner exact HEAD declaration harus ada tepat satu.'
    }
    $placeholderDeclaration = 'const EXPECTED_HEAD_SHA: String = "'+$QaHeadPlaceholder+'"'
    if ($runner.IndexOf($placeholderDeclaration) -ge 0) { throw 'HEAD declaration placeholder belum diganti.' }
    if ($preset -notmatch ('(?m)^custom_features="'+[regex]::Escape($QaFeature)+'"$')) { throw 'QA custom feature tidak aktif.' }
    if ($preset -notmatch ('(?m)^package/unique_name="'+[regex]::Escape([string]$Info.qa_package)+'"$')) { throw 'QA package id tidak terisolasi.' }
    if ($preset -notmatch '(?m)^gradle_build/export_format=0$') { throw 'QA build harus APK.' }
    $exclude = [regex]::Match($preset,'(?m)^exclude_filter="(?<value>[^"]*)"$')
    if (-not $exclude.Success -or $exclude.Groups['value'].Value -match '(^|,)tests/\*(,|$)') { throw 'tests/android belum masuk disposable QA APK.' }
    if ($project + $preset + $runner -match 'firebase deploy|service.account|firebase login') { throw 'QA workspace berisi deployment primitive.' }
}

function Get-BridgeAar {
    $candidate = $BridgeAarPath.Trim().Trim('"')
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw 'Build/BuildRun memerlukan -BridgeAarPath ke debug AAR hasil exact-SHA GitHub Actions.'
    }
    $expected = $ExpectedBridgeAarSha256.Trim().ToLowerInvariant()
    if ($expected -notmatch '^[0-9a-f]{64}$') {
        throw 'Build/BuildRun memerlukan -ExpectedBridgeAarSha256 64 hex dari artifact CI exact-SHA.'
    }
    $actual = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "Debug bridge AAR SHA256 mismatch. expected=$expected actual=$actual" }
    return [ordered]@{ path=(Resolve-Path -LiteralPath $candidate).Path; sha256=$actual }
}

function Install-BridgeAar($Info,$Aar) {
    $target = Join-Path ([string]$Info.workspace) $QaAarRelative
    New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath ([string]$Aar.path) -Destination $target -Force
    $copied = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($copied -ne [string]$Aar.sha256) { throw 'AAR berubah saat copy ke disposable workspace.' }
}

function New-AuditReport($Info,[string]$Status) {
    return [ordered]@{
        status=$Status
        head_sha=$Info.head_sha
        production_package=$Info.production_package
        qa_package=$Info.qa_package
        source='git archive exact HEAD'
        production_worktree_mutated=$false
        firebase_production=$false
        cloud_network=$false
        restore_invoked=$false
        candidate_namespace='package-specific QA only'
        device_status='NOT_RUN'
    }
}

function Invoke-Audit {
    $head = Get-HeadSha
    $tracked = @(
        'project.godot',
        'export_presets.cfg',
        'scripts/managers/cloud_transfer_candidate_stager_qa.gd',
        'scripts/managers/cloud_registered_path_restore_qa.gd'
    )
    $hashes = @{}
    foreach ($relative in $tracked) {
        $path = Join-Path $ProjectRoot $relative
        $hashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    $workspace = $null
    try {
        $workspace = New-QaWorkspace $head
        $info = Patch-QaWorkspace $workspace $head
        Assert-QaWorkspace $info
        foreach ($relative in $tracked) {
            $path = Join-Path $ProjectRoot $relative
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $hashes[$relative]) {
                throw "Audit mutated tracked locked/production file: $relative"
            }
        }
        $report = New-AuditReport $info 'PASS'
        Write-Utf8 (Join-Path $Artifacts 'android-account-bound-transport-device-qa-audit.json') ($report | ConvertTo-Json -Depth 6)
        Write-Host 'ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_AUDIT_PASS' -ForegroundColor Green
        return $report
    }
    finally {
        if ($workspace -and (Test-Path -LiteralPath $workspace -PathType Container)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
    }
}

function Invoke-Build {
    $head = Get-HeadSha
    $godot = Get-GodotExecutable
    $aar = Get-BridgeAar
    $workspace = $null
    try {
        $workspace = New-QaWorkspace $head
        $info = Patch-QaWorkspace $workspace $head
        Assert-QaWorkspace $info
        Install-BridgeAar $info $aar
        $importResult = Invoke-NativeCaptured $godot @('--headless','--path',$workspace,'--import') 'Godot import'
        $importOutput = [string]$importResult.output
        if ($importOutput) { $importOutput | Write-Host }
        if ($importOutput -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_(?:ARMED|DEVICE_|QA_TOTAL)') {
            throw 'Godot import mengeksekusi Android device QA di host Windows.'
        }
        if ([int]$importResult.exit_code -ne 0) { throw ('Godot import QA workspace gagal. Exit code: ' + $importResult.exit_code) }
        $short = $head.Substring(0,7)
        $apk = Join-Path $Artifacts ("JadeAscendant-AccountBoundTransportQA-$short.apk")
        $buildReportPath = Join-Path $Artifacts 'android-account-bound-transport-device-qa-build.json'
        Remove-Item -LiteralPath $apk,$buildReportPath -Force -ErrorAction SilentlyContinue
        $exportResult = Invoke-NativeCaptured $godot @('--headless','--path',$workspace,'--install-android-build-template','--export-debug','Android',$apk) 'Godot Android export'
        $exportOutput = [string]$exportResult.output
        if ($exportOutput) { $exportOutput | Write-Host }
        if ($exportOutput -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_(?:ARMED|DEVICE_|QA_TOTAL)') {
            throw 'Godot export mengeksekusi Android device QA di host Windows.'
        }
        if ([int]$exportResult.exit_code -ne 0 -or -not (Test-Path -LiteralPath $apk -PathType Leaf) -or (Get-Item -LiteralPath $apk).Length -le 0) {
            throw ('Export debug APK gagal. Exit code: ' + $exportResult.exit_code)
        }
        $report = New-AuditReport $info 'PASS'
        $report.apk = $apk
        $report.apk_sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
        $report.bridge_aar_sha256 = [string]$aar.sha256
        Write-Utf8 $buildReportPath ($report | ConvertTo-Json -Depth 6)
        Write-Host "ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_BUILD_PASS | $apk" -ForegroundColor Green
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
    $candidates.Add('D:\SDK\platform-tools\adb.exe') | Out-Null
    $command = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates.Add($command.Source) | Out-Null }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    throw 'adb.exe tidak ditemukan.'
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

function Get-QaLaunchComponent([string]$Adb,[string[]]$Prefix,[string]$Package) {
    [string[]]$adbArguments = $Prefix + @('shell','cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER',$Package)
    $resolved = Invoke-NativeCaptured $Adb $adbArguments 'ADB resolve QA launcher'
    $output = ([string]$resolved.output).Trim()
    if ([int]$resolved.exit_code -ne 0) { throw "Tidak dapat resolve launcher activity QA untuk $Package." }
    $escaped = [regex]::Escape($Package)
    $components = @($output -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match ('^'+$escaped+'/[^\s]+$') })
    if ($components.Count -ne 1) { throw "Launcher QA harus resolve tepat satu component. Output: $output" }
    return [string]$components[0]
}

function Get-QaPid([string]$Adb,[string[]]$Prefix,[string]$Package) {
    [string[]]$adbArguments = $Prefix + @('shell','pidof',$Package)
    $result = Invoke-NativeCaptured $Adb $adbArguments 'ADB QA pid lookup'
    $output = ([string]$result.output).Trim()
    if ([int]$result.exit_code -ne 0 -or -not $output) { return '' }
    $ids = @($output -split '\s+' | Where-Object { $_ -match '^\d+$' })
    if ($ids.Count -ne 1) { throw "QA package harus punya tepat satu process. pidof: $output" }
    return [string]$ids[0]
}

function Test-QaAppForeground([string]$Adb,[string[]]$Prefix,[string]$Package) {
    $escaped = [regex]::Escape($Package)
    $activity = Invoke-NativeCaptured $Adb ($Prefix + @('shell','dumpsys','activity','activities')) 'ADB activity foreground check'
    if ([int]$activity.exit_code -eq 0 -and [string]$activity.output -match ('(?m)^\s*(?:topResumedActivity|mResumedActivity)=.*'+$escaped+'/')) { return $true }
    $window = Invoke-NativeCaptured $Adb ($Prefix + @('shell','dumpsys','window')) 'ADB window foreground check'
    return [int]$window.exit_code -eq 0 -and [string]$window.output -match ('(?m)^\s*(?:mCurrentFocus|mFocusedApp)=.*'+$escaped+'/')
}

function Start-QaApp([string]$Adb,[string[]]$Prefix,[string]$Package,[string]$Component) {
    $start = Invoke-NativeCaptured $Adb ($Prefix + @('shell','am','start','-W','-n',$Component)) 'ADB explicit QA launch'
    if ([int]$start.exit_code -ne 0) { throw "Explicit Android QA launch gagal. $($start.output)" }
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
        $processId = Get-QaPid $Adb $Prefix $Package
        if ($processId -and (Test-QaAppForeground $Adb $Prefix $Package)) {
            Write-Host "ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_FOREGROUND | package=$Package | component=$Component | pid=$processId" -ForegroundColor DarkCyan
            return $processId
        }
        Start-Sleep -Milliseconds 150
    }
    throw "Android QA launch tidak mencapai foreground process. package=$Package"
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
    $component = Get-QaLaunchComponent $adb $prefix $Package
    $null = Invoke-Adb $adb $prefix @('logcat','-c') $false
    $processId = Start-QaApp $adb $prefix $Package $component
    if (-not $processId) { throw 'QA process PID tidak tersedia setelah launch.' }

    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $markers = New-Object System.Collections.Generic.List[string]
    $deadline = (Get-Date).AddMinutes(3)
    $logPath = Join-Path $Artifacts 'android-account-bound-transport-device-qa.log'
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $raw = (& $adb @prefix logcat -d -v raw 2>&1 | Out-String)
        $lines = @($raw -split "`r?`n" | Where-Object { $_ -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_' })
        foreach ($line in $lines) {
            $clean = $line.Trim()
            if (-not $clean -or -not $seen.Add($clean)) { continue }
            $markers.Add($clean) | Out-Null
            Write-Host $clean -ForegroundColor Cyan
            if ($clean -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_FAIL') {
                $null = Save-DeviceLog $adb $prefix $logPath
                $summary = [ordered]@{ status='FAIL'; head_sha=$HeadSha; package=$Package; device=$serial; apk=$InputApk; markers=$markers }
                Write-Utf8 (Join-Path $Artifacts 'android-account-bound-transport-device-qa-summary.json') ($summary | ConvertTo-Json -Depth 8)
                throw 'Android account-bound transport device QA melaporkan FAIL.'
            }
            if ($clean -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_PASS') {
                if ($clean -notmatch ('head='+[regex]::Escape($HeadSha)+'(?:\s|\|)')) {
                    $null = Save-DeviceLog $adb $prefix $logPath
                    throw 'Android transport QA PASS marker berasal dari HEAD berbeda.'
                }
                $null = Save-DeviceLog $adb $prefix $logPath
                $summary = [ordered]@{
                    status='PASS'; head_sha=$HeadSha; package=$Package; device=$serial; apk=$InputApk
                    apk_sha256=(Get-FileHash -LiteralPath $InputApk -Algorithm SHA256).Hash.ToLowerInvariant()
                    markers=$markers
                }
                Write-Utf8 (Join-Path $Artifacts 'android-account-bound-transport-device-qa-summary.json') ($summary | ConvertTo-Json -Depth 8)
                if (-not $KeepApp) { $null = Invoke-Adb $adb $prefix @('uninstall',$Package) $true }
                Write-Host 'ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_QA_PASS' -ForegroundColor Green
                return $summary
            }
        }
    }
    $null = Save-DeviceLog $adb $prefix $logPath
    throw 'Android account-bound transport device QA timeout.'
}

function Find-LatestQaApk {
    if ($ApkPath) { return (Resolve-Path -LiteralPath $ApkPath).Path }
    $latest = Get-ChildItem -LiteralPath $Artifacts -Filter 'JadeAscendant-AccountBoundTransportQA-*.apk' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
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
