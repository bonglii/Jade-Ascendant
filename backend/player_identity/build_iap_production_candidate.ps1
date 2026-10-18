param([string]$SdkRoot = 'D:\SDK', [string]$GradlePath = '')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$names = @('ANDROID_HOME','ANDROID_SDK_ROOT','JADE_IAP_TARGET','JADE_IAP_SANDBOX_CREDIT','JADE_IAP_GAMEPLAY_V2','JADE_IAP_PRODUCTION_CANDIDATE')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
$work = $null
try {
    if (-not (Test-Path -LiteralPath (Join-Path $SdkRoot 'platforms/android-36/android.jar'))) { throw 'Android SDK 36 is required.' }
    if (-not $GradlePath) { $GradlePath = (Get-Command gradle.bat -ErrorAction Stop).Source }
    if (-not (Test-Path -LiteralPath $GradlePath)) { throw 'Gradle launcher missing.' }
    $javap = Join-Path $env:JAVA_HOME 'bin/javap.exe'
    if (-not (Test-Path -LiteralPath $javap)) { throw 'Complete JDK 17 with javap is required.' }
    $env:ANDROID_HOME = $SdkRoot; $env:ANDROID_SDK_ROOT = $SdkRoot
    $env:JADE_IAP_TARGET = 'production-candidate'
    $env:JADE_IAP_PRODUCTION_CANDIDATE = 'on'
    $env:JADE_IAP_SANDBOX_CREDIT = 'off'; $env:JADE_IAP_GAMEPLAY_V2 = 'on'
    $build = Join-Path $repo 'backend/monetization/android_bridge'
    # Candidate output is separate. Never copy into addons or deploy a Worker.
    $parent = Join-Path $repo '.local/production_native_candidate'
    $work = Join-Path $parent ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    & $GradlePath -p $build --no-daemon :bridge:testDebugUnitTest :bridge:testReleaseUnitTest :bridge:assembleRelease
    if ($LASTEXITCODE -ne 0) { throw 'Candidate compile/unit tests failed. Installed AARs unchanged.' }
    $dependencies = @(& $GradlePath -p $build --no-daemon :bridge:dependencies --configuration releaseRuntimeClasspath)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect release dependencies.' }
    $dependencyText = $dependencies -join "`n"
    if ($dependencyText -match 'firebase-appcheck-debug' -or $dependencyText -notmatch 'firebase-appcheck-playintegrity') { throw 'Release App Check dependencies invalid.' }
    [IO.File]::WriteAllText((Join-Path $work 'release-dependencies.txt'),$dependencyText)
    $outputs = @(Get-ChildItem -LiteralPath (Join-Path $build 'bridge/build/outputs/aar') -Filter '*-release.aar')
    if ($outputs.Count -ne 1) { throw 'Ambiguous release candidate output.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $jar = Join-Path $work 'classes.jar'
    $archive = [IO.Compression.ZipFile]::OpenRead($outputs[0].FullName)
    try {
        $entry = $archive.GetEntry('classes.jar')
        if ($null -eq $entry) { throw 'Candidate has no classes.jar.' }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$jar,$true)
    } finally { $archive.Dispose() }
    $ns = 'com.yungdevstudio.jadeascendant.monetizationbridge.'
    $flags = @(& $javap -classpath $jar -constants ($ns + 'BuildConfig')) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect candidate flags.' }
    foreach ($required in @('DEBUG = false','JADE_IAP_PRODUCTION_CANDIDATE_ENABLED = true','JADE_IAP_STAGING_CREDIT_ENABLED = false','JADE_IAP_GAMEPLAY_V2_ENABLED = true','JADE_IAP_TARGET = "production-candidate"','JADE_IAP_WORKER_BASE_URL = "https://jade-ascendant-iap.jade-ascendant-studio.workers.dev"')) {
        if (-not $flags.Contains($required)) { throw ('Candidate flag mismatch: ' + $required) }
    }
    $contract = @(& $javap -classpath $jar -public ($ns + 'JadeMonetizationNativeBridge')) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect candidate JNI.' }
    $source = [IO.File]::ReadAllText((Join-Path $build 'bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/JadeMonetizationNativeBridge.kt'))
    $methods = @([regex]::Matches($source,'@UsedByGodot\s+fun\s+(\w+)'))
    if ($methods.Count -lt 10) { throw 'JNI inventory incomplete.' }
    foreach ($method in $methods) {
        if ($contract -notmatch ('\b' + [regex]::Escape($method.Groups[1].Value) + '\(')) { throw ('Candidate JNI missing: ' + $method.Groups[1].Value) }
    }
    $provider = @(& $javap -classpath $jar -c -p ($ns + 'AppCheckProviderInstall')) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $provider -notmatch 'PlayIntegrityAppCheckProviderFactory' -or $provider -match 'DebugAppCheckProviderFactory') { throw 'Release must install Play Integrity provider.' }
    $xml = @(Get-ChildItem -LiteralPath (Join-Path $build 'bridge/build/test-results') -Recurse -Filter 'TEST-*.xml')
    if ($xml.Count -eq 0) { throw 'Missing JVM test receipts.' }
    $tests = 0
    foreach ($variant in @('Debug','Release')) {
        $policy = Join-Path $build ('bridge/build/test-results/test' + $variant + 'UnitTest/TEST-com.yungdevstudio.jadeascendant.monetizationbridge.IapTransportPolicyTest.xml')
        if (-not (Test-Path -LiteralPath $policy)) { throw ('Missing policy tests for ' + $variant) }
        $policyReport = [xml][IO.File]::ReadAllText($policy)
        if ([int]$policyReport.testsuite.tests -lt 4 -or [int]$policyReport.testsuite.skipped -ne 0) { throw ('Incomplete policy execution: ' + $variant) }
    }
    foreach ($variant in @('Debug','Release')) {
        $eventTests = Join-Path $build ('bridge/build/test-results/test' + $variant + 'UnitTest/TEST-com.yungdevstudio.jadeascendant.monetizationbridge.OdysseyContractV1Test.xml')
        if (-not (Test-Path -LiteralPath $eventTests)) { throw ('Missing Odyssey contract tests for ' + $variant) }
        $eventReport = [xml][IO.File]::ReadAllText($eventTests)
        if ([int]$eventReport.testsuite.tests -ne 3 -or [int]$eventReport.testsuite.skipped -ne 0) { throw 'Incomplete Odyssey JVM execution.' }
    }
    foreach ($file in $xml) {
        $report = [xml][IO.File]::ReadAllText($file.FullName)
        if ([int]$report.testsuite.failures -ne 0 -or [int]$report.testsuite.errors -ne 0) { throw 'JVM failure in candidate receipts.' }
        $tests += [int]$report.testsuite.tests
    }
    $inputs = @{}
    $inputFiles = @(Get-ChildItem -LiteralPath (Join-Path $build 'bridge/src') -Recurse -Filter '*.kt' -File)
    foreach ($path in @('backend/monetization/android_bridge/build.gradle.kts','backend/monetization/android_bridge/settings.gradle.kts','backend/monetization/android_bridge/bridge/build.gradle.kts','addons/JadeMonetizationNativeBridge/export_plugin.gd','backend/monetization/android_bridge/bridge/src/test/resources/odyssey_snapshot_v1.json')) { $inputFiles += Get-Item -LiteralPath (Join-Path $repo $path) }
    foreach ($file in $inputFiles) {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($file.FullName).Replace("`r`n","`n"))))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
        $inputs[$file.FullName.Substring($repo.Length + 1).Replace('\','/')] = $hash
    }
    $destination = Join-Path $work 'JadeMonetizationNativeBridge-production-candidate.aar'
    Copy-Item -LiteralPath $outputs[0].FullName -Destination $destination
    $receipt = @{version=1; target='production-candidate'; installed=$false; deployed=$false; inputs=$inputs;
        aar_sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant();
        compiled_utc=[DateTime]::UtcNow.ToString('o'); jvm_test_executions=$tests;
        evidence='COMPILE_JVM_JNI_PLAY_INTEGRITY_PROVIDER_ONLY_NOT_LIVE_PLAY'}
    [IO.File]::WriteAllText((Join-Path $work 'receipt.json'),($receipt | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $work 'compiled-flags.txt'),$flags)
    [IO.File]::WriteAllText((Join-Path $work 'jni.txt'),$contract)
    Remove-Item -LiteralPath $jar
    Write-Host ('PRODUCTION_CANDIDATE_BUILD=PASS; INSTALLED=NONE; DEPLOY=NONE; OUTPUT=' + $work)
    Write-Host 'Not production payment approval. Play-installed App Check, account switch and credited-order refund evidence remain required.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
}
