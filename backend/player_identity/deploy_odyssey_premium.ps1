$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production contract failed. No deployment attempted.' }
    & node --test backend/monetization/cloudflare/odyssey.test.mjs backend/monetization/cloudflare/tests/worker_paid_production_v2.test.mjs backend/player_identity/odyssey.test.mjs backend/player_identity/odyssey_dashboard.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Odyssey release checks failed. No deployment attempted.' }
    $profileConfig=Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $profileConfig)) { throw 'Existing profile configuration is missing.' }
    $profileText=[IO.File]::ReadAllText($profileConfig)
    if ($profileText -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $profileText -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $profileText -notmatch '(?m)^binding\s*=\s*"ODYSSEY_IAP"\s*$') { throw 'Unexpected profile worker or missing Odyssey binding.' }
    $iapConfig=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $iapText=[IO.File]::ReadAllText($iapConfig)
    if ($iapText -notmatch '(?m)^ODYSSEY_AD_UNIT\s*=' -or $iapText -notmatch '(?m)^ODYSSEY_AD_REWARD_ITEM\s*=') { throw 'Existing AdMob SSV configuration is missing. Preserve/configure it before this update.' }
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard asset preparation failed.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $iapConfig
    if ($LASTEXITCODE -ne 0) { throw 'IAP event update failed. No schema, secrets or event schedule were changed.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $profileConfig
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard update failed. Economy v2 is deployed; rerun this command to finish the dashboard.' }
    Write-Host 'ODYSSEY_PREMIUM_DEPLOY=PASS; ECONOMY_V1=25/100; ECONOMY_V2=10/40; SCHEMA_UNCHANGED; SECRETS_UNCHANGED; PLAYER_PROGRESS_PRESERVED'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
