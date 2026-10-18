$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production release contract failed.' }
    & node --test backend/player_identity/update_push.test.mjs backend/player_identity/announcements.test.mjs backend/monetization/cloudflare/tests/update_push_gateway.test.mjs backend/monetization/cloudflare/tests/worker_paid_production_v2.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Update notification server tests failed. No deployment attempted.' }
    $profile=Join-Path $PSScriptRoot 'wrangler.local.toml'
    $config=[IO.File]::ReadAllText($profile)
    if ($config -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $config -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $config -notmatch '(?m)^binding\s*=\s*"ODYSSEY_IAP"\s*$') { throw 'Unexpected existing profile configuration or missing service binding.' }
    $schema=Join-Path $PSScriptRoot 'update_push_schema.sql'
    & npx.cmd --yes wrangler@4.151.0 d1 execute jade-player-identities --remote --config $profile --file $schema --yes
    if ($LASTEXITCODE -ne 0) { throw 'Notification audit schema failed. No worker deployment attempted.' }
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard assets failed.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config backend/monetization/cloudflare/wrangler.production-live.toml
    if ($LASTEXITCODE -ne 0) { throw 'FCM sender deployment failed. Rerun this deployment command.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $profile
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard deployment failed. Rerun this deployment command.' }
    Write-Host 'UPDATE_NOTIFICATIONS_DEPLOY=PASS; BROADCAST=NONE; SECRETS=UNCHANGED; PAYMENT_AND_PLAYER_RECORDS=PRESERVED'
    Write-Host 'Open admin > Pengumuman > Cek koneksi Firebase. This validates only; nothing is sent.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
