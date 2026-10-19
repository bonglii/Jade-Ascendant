$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production release contract failed. No deploy attempted.' }
    & node --test backend/monetization/cloudflare/tests/odyssey_purchase_bonus.test.mjs backend/monetization/cloudflare/tests/update_push_gateway.test.mjs backend/monetization/cloudflare/tests/worker_paid_production_v2.test.mjs backend/player_identity/update_push.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Batch server validation failed. No deploy attempted.' }
    $profile=Join-Path $PSScriptRoot 'wrangler.local.toml'
    $iap=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    $pc=[IO.File]::ReadAllText($profile); $ic=[IO.File]::ReadAllText($iap)
    if ($pc -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $pc -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $pc -notmatch '(?m)^binding\s*=\s*"ODYSSEY_IAP"\s*$') { throw 'Unexpected profile target or missing IAP service binding.' }
    if ($ic -notmatch '(?m)^name\s*=\s*"jade-ascendant-iap"\s*$' -or $ic -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected production IAP database or worker.' }
    # One additive schema. Rollout cutoff uses INSERT OR IGNORE and survives retries.
    & npx.cmd --yes wrangler@4.151.0 d1 execute jade-iap-ledger --remote --config $iap --file backend/monetization/cloudflare/migrations/0015_odyssey_topup_bonus.sql --yes
    if ($LASTEXITCODE -ne 0) { throw 'Dice bonus schema failed. No Worker deployment attempted.' }
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard asset build failed.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $iap
    if ($LASTEXITCODE -ne 0) { throw 'IAP event worker deploy failed. Completed schema is retained.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $profile
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard deploy failed. Retry this launcher.' }
    Write-Host 'ODYSSEY_SHOP_DEPLOY=PASS; BONUS_CUTOFF_PRESERVED; EVENT_SCHEDULE_UNCHANGED; PAYMENT_GATES_UNCHANGED; BROADCAST=NONE'
    Write-Host 'Dashboard > Pengumuman > Cek koneksi Firebase validates the actual sender. No push is sent by this launcher.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
