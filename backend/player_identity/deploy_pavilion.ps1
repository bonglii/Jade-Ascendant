$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($scriptName in @('deploy_pavilion.ps1','publish_pavilion.ps1')) {
        $parseTokens = $null
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $scriptName), [ref]$parseTokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw ('PowerShell parse check failed: ' + $scriptName + ': ' + $parseErrors[0].Message) }
    }
    & node --test identity.test.mjs mail.test.mjs pavilion.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed; deployment stopped.' }
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw 'Existing dashboard deployment configuration is required. Run this from the deployment laptop.' }
    $configText = [IO.File]::ReadAllText($config)
    if ($configText -notmatch '(?m)^binding\s*=\s*"PROFILE_DB"\s*$' -or $configText -notmatch '(?m)^binding\s*=\s*"ASSETS"\s*$') { throw 'Existing PROFILE_DB and ASSETS bindings are required. Preserve the configuration and deploy the working Mail Studio first.' }
    & node build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard assets failed to build.' }
    & npx.cmd --yes wrangler@4 d1 execute PROFILE_DB --config $config --remote --file pavilion_schema.sql --yes
    if ($LASTEXITCODE -ne 0) { throw 'Banner schema deployment failed. Existing player/mail records are preserved.' }
    & npx.cmd --yes wrangler@4 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Worker deployment failed. Retry this launcher; banner schema is idempotent.' }
    Write-Host 'PAVILION_SERVER_DEPLOY=PASS'
    Write-Host 'ADMIN_DASHBOARD_URL=https://jade-ascendant-player.jade-ascendant-studio.workers.dev/admin'
    Write-Host 'Next: re-export Android once. Open dashboard with backend\player_identity\open_mail_dashboard.cmd and select Banner gacha.'
    Write-Host 'Existing admin account, password, player UID, mail and claim receipts are unchanged.'
} catch {
    Write-Error $_
    exit 1
} finally { Pop-Location }
