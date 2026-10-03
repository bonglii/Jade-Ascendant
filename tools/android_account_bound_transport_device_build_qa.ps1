param(
    [ValidateSet('Audit','Smoke','Build')][string]$Action = 'Audit',
    [string]$GodotPath = '',
    [string]$BridgeAarPath = '',
    [string]$ExpectedBridgeAarSha256 = '',
    [ValidateRange(30,1800)][int]$ImportTimeoutSeconds = 420,
    [ValidateRange(15,600)][int]$PluginSmokeTimeoutSeconds = 120,
    [ValidateRange(60,3600)][int]$ExportTimeoutSeconds = 900
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

function Invoke-NativeTimed(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$Label,
    [string]$WorkingDirectory,
    [int]$TimeoutSeconds
) {
    if ($TimeoutSeconds -lt 1) { throw "$Label timeout harus positif." }
    foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            throw "$Label menggunakan argument dengan whitespace/quote yang tidak didukung harness fail-closed: $argument"
        }
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.Arguments = ($Arguments -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "$Label gagal start." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        $childProcessId = $process.Id
        try {
            & taskkill.exe /PID $childProcessId /T /F 1>$null 2>$null
        }
        catch {
            # Best effort; Process.Kill below remains the fallback.
        }
        if (-not $process.HasExited) {
            try { $process.Kill() } catch { }
        }
        try { $process.WaitForExit() } catch { }
    }

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $parts = New-Object System.Collections.Generic.List[string]
    if ($stdout) { $parts.Add($stdout.TrimEnd()) | Out-Null }
    if ($stderr) { $parts.Add($stderr.TrimEnd()) | Out-Null }
    $exitCode = 124
    if (-not $timedOut -and $process.HasExited) { $exitCode = [int]$process.ExitCode }
    $process.Dispose()

    return [ordered]@{
        label=$Label
        exit_code=$exitCode
        timed_out=[bool]$timedOut
        timeout_seconds=$TimeoutSeconds
        output=($parts -join [Environment]::NewLine)
    }
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
        throw "Android transport build QA dikunci ke Godot 4.7.2. Terbaca: $version"
    }
    return (Resolve-Path -LiteralPath $candidate).Path
}

function New-QaWorkspace([string]$HeadSha) {
    $name = 'jade_android_account_bound_transport_build_qa_' + [guid]::NewGuid().ToString('N')
    $root = Join-Path ([System.IO.Path]::GetTempPath()) $name
    $archive = Join-Path ([System.IO.Path]::GetTempPath()) ($name + '.zip')
    New-Item -ItemType Directory -Force $root | Out-Null
    & git -C $ProjectRoot archive --format=zip --output=$archive $HeadSha
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        throw 'git archive HEAD gagal. Build QA tidak memakai working tree langsung.'
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

function Patch-QaWorkspaceBase([string]$Workspace,[string]$HeadSha) {
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
    # Critical ordering rule: NO editor plugin may load during the expensive import phase.
    $project = Replace-ExactlyOnce $project '(?m)^enabled=PackedStringArray\([^\r\n]*\)$' 'enabled=PackedStringArray()' 'editor plugins disabled for import phase'
    $project = Replace-ExactlyOnce $project '(?m)^config/name="jade-ascendant"$' 'config/name="jade-ascendant-account-bound-transport-qa"' 'QA application name'
    if ($project -match [regex]::Escape($QaFeature)) { throw 'QA arming feature tidak boleh tracked di disposable project.godot.' }
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

function Assert-QaWorkspace($Info,[bool]$PluginEnabled) {
    $workspace = [string]$Info.workspace
    $project = [System.IO.File]::ReadAllText((Join-Path $workspace 'project.godot'))
    $preset = [System.IO.File]::ReadAllText((Join-Path $workspace 'export_presets.cfg'))
    $runner = [System.IO.File]::ReadAllText((Join-Path $workspace 'tests/android/android_account_bound_transport_device_qa.gd'))
    if ($project -notmatch [regex]::Escape('run/main_scene="'+$QaScene+'"')) { throw 'QA main scene tidak aktif.' }
    if ($PluginEnabled) {
        if ($project -notmatch ('(?m)^enabled=PackedStringArray\("'+[regex]::Escape($QaPlugin)+'"\)$')) {
            throw 'Export phase harus mengaktifkan hanya JadeCloudNativeBridge.'
        }
    }
    else {
        if ($project -notmatch '(?m)^enabled=PackedStringArray\(\)$') {
            throw 'Import phase harus menonaktifkan seluruh editor plugin.'
        }
        if ($project -match [regex]::Escape('enabled=PackedStringArray("'+$QaPlugin+'")')) {
            throw 'JadeCloudNativeBridge tidak boleh aktif selama import phase.'
        }
    }
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

function Enable-QaExportPlugin($Info) {
    $projectPath = Join-Path ([string]$Info.workspace) 'project.godot'
    $project = [System.IO.File]::ReadAllText($projectPath)
    $project = Replace-ExactlyOnce $project '(?m)^enabled=PackedStringArray\(\)$' ('enabled=PackedStringArray("'+$QaPlugin+'")') 'enable bridge only after import'
    Write-Utf8 $projectPath $project
    Assert-QaWorkspace $Info $true
}

function Get-BridgeAar {
    $candidate = $BridgeAarPath.Trim().Trim('"')
    if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw 'Build memerlukan -BridgeAarPath ke debug AAR hasil GitHub Actions yang sudah diverifikasi.'
    }
    $expected = $ExpectedBridgeAarSha256.Trim().ToLowerInvariant()
    if ($expected -notmatch '^[0-9a-f]{64}$') {
        throw 'Build memerlukan -ExpectedBridgeAarSha256 64 hex.'
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

function Invoke-ImportPhase($Info,[string]$Godot) {
    Assert-QaWorkspace $Info $false
    $result = Invoke-NativeTimed $Godot @('--headless','--path','.','--import') 'Godot disposable import' ([string]$Info.workspace) $ImportTimeoutSeconds
    $output = [string]$result.output
    if ($output) { $output | Write-Host }
    if ([bool]$result.timed_out) { throw "Godot disposable import timeout setelah $ImportTimeoutSeconds detik. Editor plugin tetap OFF; build dihentikan fail-closed." }
    if ($output -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_(?:ARMED|DEVICE_|QA_TOTAL)') {
        throw 'Godot import mengeksekusi Android device QA di host Windows.'
    }
    if ([int]$result.exit_code -ne 0) { throw ('Godot disposable import gagal. Exit code: ' + $result.exit_code) }
    Write-Host 'ANDROID_ACCOUNT_BOUND_TRANSPORT_IMPORT_PHASE_PASS' -ForegroundColor Green
}

function Invoke-PluginSmoke($Info,[string]$Godot) {
    Enable-QaExportPlugin $Info
    # Godot --export-debug implies an import pass. Re-run a warm import with the
    # bridge enabled so CI exercises that exact startup condition before APK build.
    $result = Invoke-NativeTimed $Godot @('--headless','--path','.','--import') 'Godot bridge warm-import smoke' ([string]$Info.workspace) $PluginSmokeTimeoutSeconds
    $output = [string]$result.output
    if ($output) { $output | Write-Host }
    if ([bool]$result.timed_out) { throw "Godot bridge warm-import smoke timeout setelah $PluginSmokeTimeoutSeconds detik." }
    if ($output -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_(?:ARMED|DEVICE_|QA_TOTAL)') {
        throw 'Bridge warm-import smoke mengeksekusi Android device QA di host Windows.'
    }
    if ([int]$result.exit_code -ne 0) { throw ('Godot bridge warm-import smoke gagal. Exit code: ' + $result.exit_code) }
    Write-Host 'ANDROID_ACCOUNT_BOUND_TRANSPORT_PLUGIN_SMOKE_PASS' -ForegroundColor Green
}

function Assert-ProductionWorktreeUnchanged($BeforeHashes) {
    foreach ($relative in $BeforeHashes.Keys) {
        $path = Join-Path $ProjectRoot $relative
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $BeforeHashes[$relative]) {
            throw "Build harness mutated tracked locked/production file: $relative"
        }
    }
}

function Get-TrackedHashes {
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
    return $hashes
}

function Invoke-Audit {
    $head = Get-HeadSha
    $hashes = Get-TrackedHashes
    $workspace = $null
    try {
        $workspace = New-QaWorkspace $head
        $info = Patch-QaWorkspaceBase $workspace $head
        Assert-QaWorkspace $info $false
        Enable-QaExportPlugin $info
        Assert-ProductionWorktreeUnchanged $hashes
        Write-Host 'ANDROID_ACCOUNT_BOUND_TRANSPORT_BUILD_HARNESS_AUDIT_PASS' -ForegroundColor Green
    }
    finally {
        if ($workspace -and (Test-Path -LiteralPath $workspace -PathType Container)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
    }
}

function Invoke-Smoke {
    $head = Get-HeadSha
    $godot = Get-GodotExecutable
    $hashes = Get-TrackedHashes
    $workspace = $null
    try {
        $workspace = New-QaWorkspace $head
        $info = Patch-QaWorkspaceBase $workspace $head
        Invoke-ImportPhase $info $godot
        Invoke-PluginSmoke $info $godot
        Assert-ProductionWorktreeUnchanged $hashes
        Write-Host 'ANDROID_ACCOUNT_BOUND_TRANSPORT_BUILD_SMOKE_PASS' -ForegroundColor Green
    }
    finally {
        if ($workspace -and (Test-Path -LiteralPath $workspace -PathType Container)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
    }
}

function Invoke-Build {
    $head = Get-HeadSha
    $godot = Get-GodotExecutable
    $aar = Get-BridgeAar
    $hashes = Get-TrackedHashes
    $workspace = $null
    try {
        $workspace = New-QaWorkspace $head
        $info = Patch-QaWorkspaceBase $workspace $head
        Invoke-ImportPhase $info $godot
        Install-BridgeAar $info $aar
        Invoke-PluginSmoke $info $godot

        $short = $head.Substring(0,7)
        $workspaceArtifacts = Join-Path $workspace 'artifacts'
        New-Item -ItemType Directory -Force $workspaceArtifacts | Out-Null
        $relativeApk = 'artifacts/JadeAscendant-AccountBoundTransportQA-'+$short+'.apk'
        $workspaceApk = Join-Path $workspace ('artifacts\JadeAscendant-AccountBoundTransportQA-'+$short+'.apk')
        $destinationApk = Join-Path $Artifacts ('JadeAscendant-AccountBoundTransportQA-'+$short+'.apk')
        $buildReportPath = Join-Path $Artifacts 'android-account-bound-transport-device-qa-build.json'
        Remove-Item -LiteralPath $destinationApk,$buildReportPath -Force -ErrorAction SilentlyContinue

        $exportResult = Invoke-NativeTimed $godot @('--headless','--path','.','--install-android-build-template','--export-debug','Android',$relativeApk) 'Godot Android export' $workspace $ExportTimeoutSeconds
        $exportOutput = [string]$exportResult.output
        if ($exportOutput) { $exportOutput | Write-Host }
        if ([bool]$exportResult.timed_out) { throw "Godot Android export timeout setelah $ExportTimeoutSeconds detik." }
        if ($exportOutput -match 'JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_(?:ARMED|DEVICE_|QA_TOTAL)') {
            throw 'Godot export mengeksekusi Android device QA di host Windows.'
        }
        if ([int]$exportResult.exit_code -ne 0 -or -not (Test-Path -LiteralPath $workspaceApk -PathType Leaf) -or (Get-Item -LiteralPath $workspaceApk).Length -le 0) {
            throw ('Export debug APK gagal. Exit code: ' + $exportResult.exit_code)
        }
        Copy-Item -LiteralPath $workspaceApk -Destination $destinationApk -Force
        if (-not (Test-Path -LiteralPath $destinationApk -PathType Leaf) -or (Get-Item -LiteralPath $destinationApk).Length -le 0) {
            throw 'APK QA gagal disalin dari disposable workspace.'
        }

        Assert-ProductionWorktreeUnchanged $hashes
        $report = [ordered]@{
            status='PASS'
            head_sha=$head
            source='git archive exact HEAD'
            apk=$destinationApk
            apk_sha256=(Get-FileHash -LiteralPath $destinationApk -Algorithm SHA256).Hash.ToLowerInvariant()
            bridge_aar_sha256=[string]$aar.sha256
            import_timeout_seconds=$ImportTimeoutSeconds
            plugin_smoke_timeout_seconds=$PluginSmokeTimeoutSeconds
            export_timeout_seconds=$ExportTimeoutSeconds
            production_worktree_mutated=$false
            firebase_production=$false
            cloud_network=$false
            restore_invoked=$false
            device_status='NOT_RUN'
        }
        Write-Utf8 $buildReportPath ($report | ConvertTo-Json -Depth 6)
        Write-Host "ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_BUILD_PASS | $destinationApk" -ForegroundColor Green
    }
    finally {
        if ($workspace -and (Test-Path -LiteralPath $workspace -PathType Container)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
    }
}

try {
    Set-Location -LiteralPath $ProjectRoot
    switch ($Action) {
        'Audit' { Invoke-Audit }
        'Smoke' { Invoke-Smoke }
        'Build' { Invoke-Build }
    }
    exit 0
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
