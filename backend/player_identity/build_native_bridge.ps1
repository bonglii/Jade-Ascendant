param(
    [string]$SdkRoot = 'D:\SDK',
    [ValidateSet('locked','staging')][string]$Target = 'locked',
    [switch]$SandboxCredit,
    [string]$GradlePath = ''
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$oldTarget = $env:JADE_IAP_TARGET
$oldCredit = $env:JADE_IAP_SANDBOX_CREDIT
$oldSdk = $env:ANDROID_HOME
$oldSdkRoot = $env:ANDROID_SDK_ROOT
$work = $null
$backups = @()
$written = @()
$keepWork = $false
try {
    if ($SandboxCredit -and $Target -ne 'staging') { throw 'Sandbox credit requires -Target staging.' }
    if (-not (Test-Path -LiteralPath (Join-Path $SdkRoot 'platforms\android-36\android.jar'))) { throw ('Android SDK 36 was not found in: ' + $SdkRoot) }
    if ($env:JAVA_HOME -and (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\javac.exe'))) {
        $jdk = $env:JAVA_HOME
    } else {
        $javac = (Get-Command javac.exe -ErrorAction Stop).Source
        $jdk = Split-Path (Split-Path $javac -Parent) -Parent
    }
    $javap = Join-Path $jdk 'bin\javap.exe'
    if (-not (Test-Path -LiteralPath $javap)) { throw 'A complete JDK 17 or 21 is required (javap missing).' }
    $cache = Join-Path $env:LOCALAPPDATA 'JadeAscendant\BuildTools'
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    if (-not $GradlePath) {
        $GradlePath = Join-Path $cache 'gradle-8.13\bin\gradle.bat'
        if (-not (Test-Path -LiteralPath $GradlePath)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $zip = Join-Path $cache 'gradle-8.13-bin.zip'
            $expected = ([string](Invoke-WebRequest -UseBasicParsing -Uri 'https://services.gradle.org/distributions/gradle-8.13-bin.zip.sha256').Content).Trim()
            if ($expected -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid official Gradle checksum.' }
            Invoke-WebRequest -UseBasicParsing -Uri 'https://services.gradle.org/distributions/gradle-8.13-bin.zip' -OutFile $zip
            if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $expected) { throw 'Gradle checksum mismatch. Nothing installed.' }
            Expand-Archive -LiteralPath $zip -DestinationPath $cache -Force
        }
    }
    if (-not (Test-Path -LiteralPath $GradlePath)) { throw 'Gradle launcher was not found.' }
    $env:ANDROID_HOME = $SdkRoot
    $env:ANDROID_SDK_ROOT = $SdkRoot
    $env:JADE_IAP_TARGET = $Target
    $env:JADE_IAP_SANDBOX_CREDIT = 'off'
    if ($SandboxCredit) { $env:JADE_IAP_SANDBOX_CREDIT = 'on' }
    $build = Join-Path $repo 'backend\monetization\android_bridge'
    & $GradlePath ('-Dorg.gradle.java.home=' + $jdk) -p $build --no-daemon :bridge:testDebugUnitTest :bridge:testReleaseUnitTest :bridge:assembleDebug :bridge:assembleRelease
    if ($LASTEXITCODE -ne 0) { throw 'Native compilation/tests failed. Installed AAR files were not changed.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $work = Join-Path $cache ('verify-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    $source = [IO.File]::ReadAllText((Join-Path $build 'bridge\src\main\java\com\yungdevstudio\jadeascendant\monetizationbridge\JadeMonetizationNativeBridge.kt'))
    $methods = @([regex]::Matches($source, '@UsedByGodot\s+fun\s+(\w+)') | ForEach-Object { $_.Groups[1].Value })
    if ($methods.Count -lt 10) { throw 'JNI source method inventory is unexpectedly incomplete.' }
    $artifacts = @()
    foreach ($variant in @('debug','release')) {
        $aar = @(Get-ChildItem -LiteralPath (Join-Path $build 'bridge\build\outputs\aar') -Filter ('*-' + $variant + '.aar'))
        if ($aar.Count -ne 1) { throw ('Ambiguous ' + $variant + ' AAR output.') }
        $jar = Join-Path $work ($variant + '-classes.jar')
        $archive = [IO.Compression.ZipFile]::OpenRead($aar[0].FullName)
        try {
            $entry = $archive.GetEntry('classes.jar')
            if ($null -eq $entry) { throw 'AAR contains no classes.jar.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $jar, $true)
        } finally { $archive.Dispose() }
        $contract = (& $javap -classpath $jar -public 'com.yungdevstudio.jadeascendant.monetizationbridge.JadeMonetizationNativeBridge') -join "`n"
        if ($LASTEXITCODE -ne 0 -or $contract -notmatch 'org\.godotengine\.godot\.Godot') { throw 'Godot bridge constructor missing.' }
        foreach ($method in $methods) { if ($contract -notmatch ('\b' + [regex]::Escape($method) + '\(')) { throw ('Missing JNI method: ' + $method) } }
        $flags = (& $javap -classpath $jar -constants 'com.yungdevstudio.jadeascendant.monetizationbridge.BuildConfig') -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect compiled BuildConfig.' }
        if ($variant -eq 'release' -and ($flags -notmatch 'iap-disabled\.invalid' -or $flags -notmatch 'JADE_IAP_STAGING_CREDIT_ENABLED = false')) { throw 'Release must remain locked.' }
        $destination = Join-Path $repo ('addons\JadeMonetizationNativeBridge\bin\' + $variant + '\JadeMonetizationNativeBridge-' + $variant + '.aar')
        $artifacts += @{ Source = $aar[0].FullName; Destination = $destination; Variant = $variant }
    }
    # Validate both variants before replacing either. Roll back both on copy failure.
    foreach ($artifact in $artifacts) {
        $backup = Join-Path $work ($artifact.Variant + '-original.aar')
        if (-not (Test-Path -LiteralPath $artifact.Destination)) { throw 'Existing native AAR is missing; no replacement performed.' }
        Copy-Item -LiteralPath $artifact.Destination -Destination $backup
        $backups += @{ Source = $backup; Destination = $artifact.Destination }
    }
    foreach ($artifact in $artifacts) {
        $written += $artifact.Destination
        Copy-Item -LiteralPath $artifact.Source -Destination $artifact.Destination -Force
        if ((Get-FileHash -LiteralPath $artifact.Source).Hash -ne (Get-FileHash -LiteralPath $artifact.Destination).Hash) { throw 'AAR copy verification failed.' }
        $receipt = @{
            version = 1
            variant = $artifact.Variant
            aar_sha256 = (Get-FileHash -LiteralPath $artifact.Destination -Algorithm SHA256).Hash.ToLowerInvariant()
            bridge_source_sha256 = (Get-FileHash -LiteralPath (Join-Path $build 'bridge\src\main\java\com\yungdevstudio\jadeascendant\monetizationbridge\JadeMonetizationNativeBridge.kt') -Algorithm SHA256).Hash.ToLowerInvariant()
            target = $(if ($artifact.Variant -eq 'release') { 'locked' } else { $Target })
            compiled_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
            evidence = 'COMPILE_JVM_JNI_ONLY_NOT_LIVE_PLAY'
        } | ConvertTo-Json
        $receiptDir = Join-Path $repo '.local\native_bridge_receipts'
        New-Item -ItemType Directory -Force -Path $receiptDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $receiptDir ($artifact.Variant + '.json')),$receipt,(New-Object Text.UTF8Encoding($false)))
    }
    Write-Host ('NATIVE_BUILD=PASS; DEBUG_TARGET=' + $Target + '; RELEASE=LOCKED; JNI=PASS')
    Write-Host 'Re-export Android. This is compilation/contract evidence, not a live Play purchase result.'
} catch {
    foreach ($backup in $backups) {
        if ($written -contains $backup.Destination) {
            try {
                Copy-Item -LiteralPath $backup.Source -Destination $backup.Destination -Force
                $variantName = (Split-Path $backup.Destination -Parent | Split-Path -Leaf)
                $receiptPath = Join-Path $repo ('.local\native_bridge_receipts\' + $variantName + '.json')
                if (Test-Path -LiteralPath $receiptPath) { Remove-Item -LiteralPath $receiptPath -Force }
            }
            catch { $keepWork = $true; Write-Host ('ROLLBACK_BACKUP_RETAINED=' + $work) }
        }
    }
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    $env:JADE_IAP_TARGET = $oldTarget
    $env:JADE_IAP_SANDBOX_CREDIT = $oldCredit
    $env:ANDROID_HOME = $oldSdk
    $env:ANDROID_SDK_ROOT = $oldSdkRoot
    if (-not $keepWork -and $work -and (Test-Path -LiteralPath $work)) { Remove-Item -LiteralPath $work -Recurse -Force }
}
