param([string]$AdUnit='', [string]$RewardItem='Dice')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    # Existing real-payment gates remain exactly as reviewed by the owner.
    & node (Join-Path $PSScriptRoot 'production_release_contract.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Production configuration failed its existing release contract.' }
    & node --test backend/monetization/cloudflare/odyssey.test.mjs backend/player_identity/odyssey.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Event server checks failed. No remote deployment attempted.' }
    $projectText=[IO.File]::ReadAllText((Join-Path $repo 'project.godot'))
    $unitMatch=[regex]::Match($projectText,'(?m)^admob/rewarded_ad_unit_id="([^"]+)"\s*$')
    if (-not $unitMatch.Success) { throw 'Existing client rewarded-unit setting was not found.' }
    $clientUnit=$unitMatch.Groups[1].Value
    if (-not $AdUnit) { $AdUnit=$clientUnit }
    if ($AdUnit -ne $clientUnit) { throw 'Use the rewarded unit configured in this client. A different unit requires a corresponding client update.' }
    $npx=(Get-Command npx.cmd -ErrorAction Stop).Source
    $profileConfig=Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $profileConfig)) { throw 'Existing profile wrangler.local.toml is required. Run the profile setup first.' }
    $profile=[IO.File]::ReadAllText($profileConfig)
    if ($profile -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $profile -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"') { throw 'Unexpected profile deployment identity.' }
    if ($profile -notmatch '(?m)^binding\s*=\s*"ODYSSEY_IAP"') { $profile += "`n[[services]]`nbinding = `"ODYSSEY_IAP`"`nservice = `"jade-ascendant-iap`"`n" }
    $iapConfig=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $iap=[IO.File]::ReadAllText($iapConfig)
    if ($AdUnit) {
        if ($AdUnit -notmatch '^ca-app-pub-[0-9]{16}/[0-9]{10}$' -or $RewardItem -notmatch '^[A-Za-z0-9 _-]{1,40}$') { throw 'Invalid AdMob rewarded unit or reward label.' }
        # Inject under [vars], without modifying a payment gate or other config.
        $iap=[regex]::Replace($iap,'(?m)^ODYSSEY_AD_(UNIT|REWARD_ITEM)\s*=.*\r?\n','')
        $iap=$iap.Replace('[vars]',('[vars]' + "`nODYSSEY_AD_UNIT = `"" + $AdUnit + "`"`nODYSSEY_AD_REWARD_ITEM = `"" + $RewardItem + "`""))
    }
    $cache=Join-Path $repo '.local/odyssey_deploy'; New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $keyPath=Join-Path $cache 'bridge-key.local.txt'
    if (-not (Test-Path -LiteralPath $keyPath)) {
        $bytes=New-Object byte[] 32; $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        [IO.File]::WriteAllText($keyPath,([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant())
    }
    $key=[IO.File]::ReadAllText($keyPath).Trim()
    if ($key -notmatch '^[a-f0-9]{64}$') { throw 'Invalid protected event bridge key.' }
    # Local files contain only public bindings/IDs. Secrets remain in ignored .local.
    [IO.File]::WriteAllText($profileConfig,$profile,(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($iapConfig,$iap,(New-Object Text.UTF8Encoding($false)))
    & $npx --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $iapConfig --file backend/monetization/cloudflare/migrations/0013_odyssey.sql --yes
    if ($LASTEXITCODE -ne 0) { throw 'Additive event schema failed. Workers were not deployed.' }
    $key | & $npx --yes wrangler@4.151.0 secret put ODYSSEY_ADMIN_KEY --config $iapConfig
    if ($LASTEXITCODE -ne 0) { throw 'IAP event bridge secret installation failed.' }
    $key | & $npx --yes wrangler@4.151.0 secret put ODYSSEY_ADMIN_KEY --config $profileConfig
    if ($LASTEXITCODE -ne 0) { throw 'Profile event bridge secret installation failed. Retry with the retained local key.' }
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Mailbox asset preparation failed.' }
    & $npx --yes wrangler@4.151.0 deploy --config $profileConfig
    if ($LASTEXITCODE -ne 0) { throw 'Profile event bridge deployment failed.' }
    & $npx --yes wrangler@4.151.0 deploy --config $iapConfig
    if ($LASTEXITCODE -ne 0) { throw 'IAP event deployment failed. Existing payment configuration was retained.' }
    Write-Host 'ODYSSEY_DEPLOY=PASS; EVENT_NOT_AUTOSTARTED; PAYMENT_GATES_UNCHANGED'
    Write-Host 'Dashboard: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin/odyssey'
    Write-Host 'AdMob SSV callback: https://jade-ascendant-iap.jade-ascendant-studio.workers.dev/v1/odyssey/ssv'
    Write-Host 'Enable Ads only after configuring the existing rewarded unit, amount 1, reward label and SSV callback in AdMob.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
