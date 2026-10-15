$ErrorActionPreference = 'Stop'
$pushed = $false
try {
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Push-Location $repo; $pushed = $true
    $config = 'backend/monetization/cloudflare/wrangler.gameplay-staging.toml'
    $text = [IO.File]::ReadAllText((Join-Path $repo $config))
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap-staging"[ \t]*\r?$' -or $text -notmatch 'c7c9841f-cbd3-4563-b13f-21ed90d45120') { throw 'Unexpected staging resource.' }
    Write-Host 'STAGING_ONLY; updates optional second tester secret and staging Worker code. Primary tester, balances, schema and production unchanged.'
    $uid = Read-Host 'Firebase Authentication UID for SECOND Google tester (not public game UID, email or account_ref)'
    if ($uid -notmatch '^[A-Za-z0-9_-]{6,128}$') { throw 'Invalid Firebase UID. Nothing changed.' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($uid)))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose(); $uid = $null }
    $digest | & npx.cmd --yes wrangler@4.151.0 secret put JADE_STAGING_SECOND_TESTER_UID_SHA256 --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Second tester secret update failed. Worker code not deployed.' }
    $digest = $null
    & npx.cmd --yes wrangler@4.151.0 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Secret was saved, but staging code deployment failed. Retry this script; no data migrations were run.' }
    Write-Host 'SECOND_TESTER_STAGING=CONFIGURED; no purchase performed. Check account isolation with in-game Copy support; an unfunded second account is expected.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { if ($pushed) { Pop-Location } }
