$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config)) { throw 'Existing profile wrangler.local.toml is required. No configuration was created or changed.' }
    $text = [IO.File]::ReadAllText($config)
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba' -or $text -notmatch '(?m)^binding\s*=\s*"ODYSSEY_IAP"\s*$') { throw 'Unexpected profile worker or missing Odyssey binding. No deployment attempted.' }
    & node --test backend/player_identity/odyssey_dashboard.test.mjs backend/player_identity/odyssey.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard checks failed. No deployment attempted.' }
    & node backend/player_identity/build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing dashboard asset preparation failed.' }
    & npx.cmd --yes wrangler@4.151.0 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Profile dashboard deployment failed.' }
    Write-Host 'ODYSSEY_DASHBOARD_DEPLOY=PASS; TIMEZONE=WIB; IAP_WORKER_UNCHANGED; SCHEMA_UNCHANGED; EVENT_NOT_AUTOSTARTED; AAB_NOT_REQUIRED'
    Write-Host 'Dashboard: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin/odyssey'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
