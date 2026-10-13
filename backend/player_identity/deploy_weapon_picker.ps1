$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & node --test identity.test.mjs mail.test.mjs pavilion.test.mjs pavilion_weapon_picker.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Backend checks failed. Deployment stopped.' }
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw 'Use the existing dashboard deployment laptop/configuration.' }
    $configText = [IO.File]::ReadAllText($config)
    if ($configText -notmatch '(?m)^binding\s*=\s*"PROFILE_DB"\s*$' -or $configText -notmatch '(?m)^binding\s*=\s*"ASSETS"\s*$') { throw 'Existing PROFILE_DB and ASSETS bindings are required. Preserve the working configuration.' }
    & node build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard asset preparation failed. Nothing deployed.' }
    & npx.cmd --yes wrangler@4 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Worker deployment failed. Retry this launcher.' }
    Write-Host 'PAVILION_WEAPON_PICKER_DEPLOY=PASS'
    Write-Host 'ADMIN_DASHBOARD_URL=https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin'
    Write-Host 'No database schema/data reset. Export Android to apply the client 1-5 unlock and target picker.'
} catch { Write-Error $_; exit 1 } finally { Pop-Location }
