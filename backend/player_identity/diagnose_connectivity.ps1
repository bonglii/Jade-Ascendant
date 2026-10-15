param([string]$SdkRoot = 'D:\SDK', [string]$Serial = '')
$ErrorActionPreference = 'Stop'
$hostNameValue = 'jade-ascendant-player.jade-ascendant-studio.workers.dev'
$package = 'com.yungdevstudio.jadeascendant'
$report = New-Object 'System.Collections.Generic.List[string]'
function Record([string]$Line) { $report.Add($Line); Write-Host $Line }
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
Record 'JADE_CONNECTIVITY_DIAGNOSTIC_V3'
Record ('PC_TIME_UTC=' + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))
Record ('HOST=' + $hostNameValue)
try {
    $addresses = @([Net.Dns]::GetHostAddresses($hostNameValue) | ForEach-Object { $_.IPAddressToString })
    Record ('SYSTEM_DNS=' + ($addresses -join ','))
} catch { Record 'SYSTEM_DNS=failed' }
if (Test-Path -LiteralPath $curl) {
    $status = & $curl -q -s -o NUL -w '%{http_code}' --connect-timeout 6 --max-time 12 ('https://' + $hostNameValue + '/health') 2>$null
    $exitCode = $LASTEXITCODE
    Record ('PC_HTTPS_HTTP=' + ($status -join '').Trim() + '; CURL_EXIT=' + $exitCode)
    foreach ($provider in @(@{Host='cloudflare-dns.com';IP='1.1.1.1';Path='/dns-query'},@{Host='dns.google';IP='8.8.8.8';Path='/resolve'})) {
        # Process-local route only, fixed resolver/hostname, no tokens and no OS DNS mutation.
        $raw = & $curl -q -s --connect-timeout 5 --max-time 8 --max-filesize 8192 --resolve ($provider.Host + ':443:' + $provider.IP) -H 'Accept: application/dns-json' ('https://' + $provider.Host + $provider.Path + '?name=' + $hostNameValue + '&type=A') 2>$null
        if ($LASTEXITCODE -eq 0) {
            try {
                $answer = ($raw -join "`n") | ConvertFrom-Json
                $ips = @($answer.Answer | Where-Object { $_.type -eq 1 -and $_.data -match '^\d{1,3}(\.\d{1,3}){3}$' } | ForEach-Object { [string]$_.data })
                Record ('ENCRYPTED_DNS_' + $provider.IP + '=' + ($ips -join ','))
            } catch { Record ('ENCRYPTED_DNS_' + $provider.IP + '=invalid_response') }
        } else { Record ('ENCRYPTED_DNS_' + $provider.IP + '=unavailable') }
    }
}
$adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
if (Test-Path -LiteralPath $adb) {
    $devices = @(& $adb devices | Where-Object { $_ -match '^([^\s]+)\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
    $prefix = @()
    $selected = $Serial
    if (-not $selected -and $devices.Count -eq 1) { $selected = $devices[0] }
    if ($selected -and $devices -contains $selected) {
        $prefix = @('-s',$selected)
        # Do not print device serial, account/token logs, private DNS provider or network dump.
        Record ('PHONE_TIME_UTC=' + ((& $adb @prefix shell date -u '+%Y-%m-%dT%H:%M:%SZ') -join '').Trim())
        $packageInfo = @(& $adb @prefix shell dumpsys package $package)
        foreach ($line in $packageInfo) {
            if ($line -match '^\s*(versionCode=\d+\b.*|versionName=[A-Za-z0-9_.-]+|android\.permission\.(?:INTERNET|ACCESS_NETWORK_STATE): granted=(?:true|false).*)$') { Record $line.Trim() }
        }
        Record 'PHONE_HTTPS=requires_in_game_retry; PC result is not phone HTTPS proof'
    } else { Record 'PHONE=not_selected_or_not_connected; connect one device or supply -Serial' }
} else { Record 'ADB=not_found' }
Record 'VPN_STATUS=not_inferred'
Record 'NOTE=DNS differences alone do not prove poisoning. No DNS/proxy/VPN settings changed.'
$destination = Join-Path ([IO.Path]::GetTempPath()) 'Jade-Connectivity-Report.txt'
[IO.File]::WriteAllLines($destination,$report,(New-Object Text.UTF8Encoding($false)))
Write-Host ('REPORT_SAVED=' + $destination)
