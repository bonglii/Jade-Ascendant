param([string]$SdkRoot = 'D:\SDK', [string]$Serial = '')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$report = New-Object 'System.Collections.Generic.List[string]'
function Record([string]$Line) { $report.Add($Line); Write-Host $Line }
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$work = Join-Path ([IO.Path]::GetTempPath()) ('jade-readiness-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    Record 'JADE_ACCOUNT_IAP_READINESS_V1'
    Record ('PC_TIME_UTC=' + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))
    Record 'MODE=READ_ONLY; DEPLOY=NONE; PURCHASE=NONE; DNS_SETTINGS=UNCHANGED'
    $pavilion = [IO.File]::ReadAllText((Join-Path $repo 'scripts\managers\pavilion_manager.gd'))
    Record ('SOURCE_PRODUCTION_PURCHASE_LOCK=' + ($pavilion -match 'const SECURE_PURCHASE_ACTIVATION_APPROVED: bool = false'))
    Record ('SOURCE_PAID_SUMMON_LOCK=' + ($pavilion -match 'const HYBRID_PAID_SUMMON_WRITE_APPROVED: bool = false'))
    $nativeSource = Join-Path $repo 'backend\monetization\android_bridge\bridge\src\main\java\com\yungdevstudio\jadeascendant\monetizationbridge\JadeMonetizationNativeBridge.kt'
    $nativeHash = (Get-FileHash -LiteralPath $nativeSource -Algorithm SHA256).Hash.ToLowerInvariant()
    foreach ($variant in @('debug','release')) {
        $aar = Join-Path $repo ('addons\JadeMonetizationNativeBridge\bin\' + $variant + '\JadeMonetizationNativeBridge-' + $variant + '.aar')
        if (-not (Test-Path -LiteralPath $aar)) { Record ('NATIVE_' + $variant.ToUpperInvariant() + '=MISSING'); continue }
        $hash = (Get-FileHash -LiteralPath $aar -Algorithm SHA256).Hash.ToLowerInvariant()
        Record ('NATIVE_' + $variant.ToUpperInvariant() + '_SHA256=' + $hash)
        # A timestamp or source edit is not evidence the installed binary was rebuilt.
        $receipt = Join-Path $repo ('.local\native_bridge_receipts\' + $variant + '.json')
        $proven = $false
        if (Test-Path -LiteralPath $receipt) {
            try {
                $meta = Get-Content -Raw -LiteralPath $receipt | ConvertFrom-Json
                $proven = $meta.aar_sha256 -eq $hash -and $meta.bridge_source_sha256 -eq $nativeHash
            } catch { $proven = $false }
        }
        # Portable build provenance can prove a shipped AAR even without a local Windows build.
        $portableReceipt = Join-Path $repo 'docs\checkpoints\DELIVERY_MOTION_NATIVE.json'
        if (-not $proven -and (Test-Path -LiteralPath $portableReceipt)) {
            try {
                $portable = Get-Content -Raw -LiteralPath $portableReceipt | ConvertFrom-Json
                $entries = @($portable.artifacts | Where-Object { $_.variant -eq $variant })
                $proven = $portable.native_contract -eq 'PASS' -and $portable.bridge_source_sha256 -eq $nativeHash -and $entries.Count -eq 1 -and $entries[0].sha256 -eq $hash
            } catch { $proven = $false }
        }
        Record ('NATIVE_' + $variant.ToUpperInvariant() + '_BRIDGE_SOURCE_MATCH=' + $proven)
    }
    if (Test-Path -LiteralPath $curl) {
        foreach ($service in @(@{Name='PROFILE';Host='jade-ascendant-player.jade-ascendant-studio.workers.dev';Service='jade-player-identity'},@{Name='IAP_STAGING';Host='jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev';Service='jade-iap-staging'})) {
            $body = Join-Path $work ($service.Name + '.json')
            # No redirects or --insecure. No Authorization or App Check tokens.
            $status = & $curl -q -s --connect-timeout 6 --max-time 12 --max-filesize 4096 -o $body -w '%{http_code}' ('https://' + $service.Host + '/health') 2>$null
            $code = $LASTEXITCODE
            Record ($service.Name + '_PC_HTTPS=' + ($status -join '').Trim() + '; CURL_EXIT=' + $code)
            if ($code -eq 0 -and ($status -join '').Trim() -eq '200') {
                try {
                    $payload = Get-Content -Raw -LiteralPath $body | ConvertFrom-Json
                    $validService = $payload.service -eq $service.Service
                    Record ($service.Name + '_HEALTH_IDENTITY=' + $validService)
                    if ($validService -and $service.Name -eq 'PROFILE') { Record ('PROFILE_HEALTH_READY=' + ($payload.ready -eq $true)) }
                    if ($validService -and $service.Name -eq 'IAP_STAGING') {
                        $activation = 'unknown'
                        if ($payload.activation -in @('tester_credit_only','locked')) { $activation = $payload.activation }
                        Record ('IAP_STAGING_ACTIVATION=' + $activation)
                        Record ('IAP_STAGING_TESTER_GUARD=' + ($payload.tester_guard -eq $true))
                    }
                } catch { Record ($service.Name + '_HEALTH=INVALID_JSON') }
            }
        }
    } else { Record 'PC_HTTPS=CURL_NOT_FOUND' }
    $adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
    if (Test-Path -LiteralPath $adb) {
        $devices = @(& $adb devices | Where-Object { $_ -match '^([^\s]+)\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
        $selected = $Serial
        if (-not $selected -and $devices.Count -eq 1) { $selected = $devices[0] }
        if ($selected -and $devices -contains $selected) {
            $prefix = @('-s',$selected)
            Record ('PHONE_TIME_UTC=' + ((& $adb @prefix shell date -u '+%Y-%m-%dT%H:%M:%SZ') -join '').Trim())
            $package = 'com.yungdevstudio.jadeascendant'
            $packageInfo = @(& $adb @prefix shell dumpsys package $package)
            $installed = $false
            foreach ($line in $packageInfo) {
                if ($line -match '^\s*(versionCode=\d+\b.*|versionName=[A-Za-z0-9_.-]+|android\.permission\.(?:INTERNET|ACCESS_NETWORK_STATE): granted=(?:true|false).*)$') { Record $line.Trim(); $installed = $true }
            }
            Record ('PHONE_PACKAGE_OBSERVED=' + $installed)
            $pidValue = ((& $adb @prefix shell pidof $package) -join '').Trim()
            if ($pidValue -match '^\d+$') {
                $log = @(& $adb @prefix logcat -d --pid=$pidValue -t 1800)
                # Whole-line grammar prevents tokens, arbitrary native errors or accounts
                # from being copied accidentally. Never print the unfiltered log.
                $safePatterns = @(
                    'JADE_IAP_AUTH_QA native=(?:true|false) sandbox=(?:true|false) appcheck_initialized=(?:true|false) transport=(?:true|false) identity=(?:true|false) pavilion_authority=(?:true|false)$',
                    'JADE_IAP_BILLING_QA (?:connecting|connected|disconnected|play_plugin_missing|connect_error code=-?\d+|query_requested count=\d+|parsed_products=\d+ positive_prices=\d+)$',
                    'ACCOUNT_LATENCY operation=(?:sign_in|sign_out|anonymous_identity|link_google) outcome=(?:callback|timeout) elapsed_ms=\d+$'
                )
                $safe = New-Object 'System.Collections.Generic.List[string]'
                foreach ($line in $log) {
                    foreach ($pattern in $safePatterns) {
                        if ($line -match $pattern) { $safe.Add($Matches[0]); break }
                    }
                }
                foreach ($line in @($safe | Select-Object -Last 24)) { Record $line }
                Record ('PHONE_SAFE_QA_LINES=' + $safe.Count)
            } else { Record 'PHONE_APP=NOT_RUNNING; open Settings or Treasury first' }
            Record 'PHONE_HTTPS=CHECK_SETTINGS_SUPPORT_REPORT; PC health is not phone connectivity proof'
        } else { Record 'PHONE=CONNECT_ONE_DEVICE_OR_SUPPLY_SERIAL' }
    } else { Record 'PHONE=ADB_NOT_FOUND' }
    Record 'NEXT=Settings > Connection > Copy support; live purchase/refund still requires Play test track'
    Record 'VPN_STATUS=NOT_INFERRED'
    $destination = Join-Path ([IO.Path]::GetTempPath()) 'Jade-Account-IAP-Readiness.txt'
    [IO.File]::WriteAllLines($destination,$report,(New-Object Text.UTF8Encoding($false)))
    Write-Host ('REPORT_SAVED=' + $destination)
    Write-Host 'READINESS_COLLECTION=PASS; this is not a production-IAP approval'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
finally { if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force } }
