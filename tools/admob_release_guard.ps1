param(
    [switch]$RequirePublisher
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Artifacts = Join-Path $ProjectRoot 'artifacts'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

$ExpectedPackageId = 'com.yungdevstudio.jadeascendant'
$GoogleSampleAndroidAppId = 'ca-app-pub-3940256099942544~3347511713'
$GoogleTestRewardedId = 'ca-app-pub-3940256099942544/5224354917'

New-Item -ItemType Directory -Force $Artifacts | Out-Null

function Write-Utf8([string]$Path,[string]$Value) {
    [System.IO.File]::WriteAllText($Path,$Value,$Utf8)
}

function Read-GodotSetting(
    [string]$Path,
    [string]$Section,
    [string]$Key
) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $text = [System.IO.File]::ReadAllText($Path)
    $header = [regex]::Match(
        $text,
        '(?m)^\[' + [regex]::Escape($Section) + '\]\s*$'
    )
    if (-not $header.Success) { return '' }

    $tail = $text.Substring($header.Index + $header.Length)
    $next = [regex]::Match($tail, '(?m)^\[')
    $length = if ($next.Success) { $next.Index } else { $tail.Length }
    $block = $tail.Substring(0, $length)

    $match = [regex]::Match(
        $block,
        '(?m)^' + [regex]::Escape($Key) + '\s*=\s*(?<value>.+?)\s*$'
    )
    if (-not $match.Success) { return '' }

    $value = $match.Groups['value'].Value.Trim()
    if (
        $value.Length -ge 2 -and
        $value.StartsWith('"') -and
        $value.EndsWith('"')
    ) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function Get-PublisherPrefix([string]$Value,[string]$Separator) {
    $index = $Value.IndexOf($Separator,[StringComparison]::Ordinal)
    if ($index -le 0) { return '' }
    return $Value.Substring(0,$index)
}

$checks = New-Object System.Collections.Generic.List[object]

function Add-Check([string]$Name,[bool]$Passed,[string]$Details) {
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }
    $checks.Add(
        [ordered]@{
            name=$Name
            status=$status
            details=$Details
        }
    ) | Out-Null

    if ($Passed) {
        Write-Host "[PASS] $Name - $Details" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Name - $Details" -ForegroundColor Red
    }
}

$projectPath = Join-Path $ProjectRoot 'project.godot'
$presetPath = Join-Path $ProjectRoot 'export_presets.cfg'

$androidEnabledRaw = Read-GodotSetting $projectPath 'admob' 'general/android/enabled'
$androidEnabled = $androidEnabledRaw
$androidEnabledDetails = "project.godot admob/general/android/enabled=$androidEnabledRaw"

if ([string]::IsNullOrWhiteSpace($androidEnabledRaw)) {
    $settingsServicePath = Join-Path $ProjectRoot 'addons/admob/internal/services/project_settings_service.gd'
    $pluginDefaultTrue = $false

    if (Test-Path -LiteralPath $settingsServicePath -PathType Leaf) {
        $settingsServiceText = [System.IO.File]::ReadAllText($settingsServicePath)
        $enabledDefaultPattern = 'SettingDefinition\.new\(\s*get_android_setting_path\("enabled"\)\s*,\s*TYPE_BOOL\s*,\s*true\s*\)'
        $pluginDefaultTrue = [regex]::IsMatch($settingsServiceText, $enabledDefaultPattern)
    }

    if ($pluginDefaultTrue) {
        $androidEnabled = 'true'
        $androidEnabledDetails = 'project.godot omits default; installed AdMob plugin default=true'
    }
    else {
        $androidEnabled = ''
        $androidEnabledDetails = 'project.godot omits value; AdMob plugin default=true could not be verified'
    }
}

$appId = Read-GodotSetting $projectPath 'admob' 'general/android/app_id'
$rewardedId = Read-GodotSetting $projectPath 'monetization' 'admob/rewarded_ad_unit_id'
$packageId = Read-GodotSetting $presetPath 'preset.0.options' 'package/unique_name'

$appIdValid = (
    $appId -match '^ca-app-pub-\d{16}~\d{10}$' -and
    $appId -ne $GoogleSampleAndroidAppId
)
$rewardedIdValid = (
    $rewardedId -match '^ca-app-pub-\d{16}/\d{10}$' -and
    $rewardedId -ne $GoogleTestRewardedId
)
$publisherMatch = (
    $appIdValid -and
    $rewardedIdValid -and
    (Get-PublisherPrefix $appId '~') -eq
    (Get-PublisherPrefix $rewardedId '/')
)

Add-Check 'AdMob Android enabled' ($androidEnabled -eq 'true') $androidEnabledDetails
Add-Check 'AdMob production App ID' $appIdValid $appId
Add-Check 'Rewarded production Ad Unit ID' $rewardedIdValid $rewardedId
Add-Check 'AdMob publisher identity match' $publisherMatch (
    'App ID dan rewarded unit harus memakai publisher ca-app-pub yang sama.'
)
Add-Check 'Final Android package ID' ($packageId -eq $ExpectedPackageId) (
    "$packageId | expected $ExpectedPackageId"
)

if ($RequirePublisher) {
    $releaseConfigPath = Join-Path $ProjectRoot 'release/release_config.json'
    $publisherConfigReady = $false
    $publisherConfigDetails = 'release/release_config.json belum ada.'
    if (Test-Path -LiteralPath $releaseConfigPath -PathType Leaf) {
        try {
            $config = Get-Content -Raw $releaseConfigPath | ConvertFrom-Json
            $configuredPackage = [string]$config.package_name
            $publisherConfigReady = ($configuredPackage -eq $ExpectedPackageId)
            $publisherConfigDetails = (
                "$configuredPackage | expected $ExpectedPackageId"
            )
        }
        catch {
            $publisherConfigDetails = $_.Exception.Message
        }
    }
    Add-Check 'Release publisher package lock' $publisherConfigReady (
        $publisherConfigDetails
    )
}

$failed = @($checks | Where-Object { $_.status -eq 'FAIL' })
$status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

$report = [ordered]@{
    timestamp=(Get-Date).ToString('o')
    status=$status
    expected_package_id=$ExpectedPackageId
    app_id=$appId
    rewarded_ad_unit_id=$rewardedId
    require_publisher=[bool]$RequirePublisher
    checks=$checks
}

$reportPath = Join-Path $Artifacts 'admob-release-guard.json'
Write-Utf8 $reportPath ($report | ConvertTo-Json -Depth 6)

if ($failed.Count -gt 0) {
    Write-Host "AdMob release guard FAIL. Laporan: $reportPath" -ForegroundColor Red
    exit 1
}

Write-Host "AdMob release guard PASS. Laporan: $reportPath" -ForegroundColor Green
exit 0
