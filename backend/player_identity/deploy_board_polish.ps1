$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production release contract failed. No deploy attempted.' }
    & node --test backend/monetization/cloudflare/tests/odyssey_board_seals.test.mjs backend/monetization/cloudflare/tests/odyssey_flow.test.mjs backend/monetization/cloudflare/tests/worker_paid_production_v2.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Board reward validation failed. No deploy attempted.' }
    $config=Join-Path $repo 'backend/monetization/cloudflare/wrangler.production-live.toml'
    & npx.cmd --yes wrangler@4.151.0 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Board reward Worker deploy failed. Rerun the same batch launcher.' }
    Write-Host 'BOARD_POLISH_DEPLOY=PASS; SCHEMA=NONE; LIVE_PAYMENT_GATES_UNCHANGED; EVENT_SCHEDULE_UNCHANGED; BOARD_SEALS_MAX=2_PER_EVENT'
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
