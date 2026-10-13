$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($file in @('deploy_reward_announcements.ps1','publish_reward_announcements.ps1')) {
        $parseTokens = $null
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $file), [ref]$parseTokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw ('PowerShell syntax check failed: ' + $file) }
    }
    & node --test announcements.test.mjs identity.test.mjs mail.test.mjs pavilion.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Server regression failed; nothing deployed.' }
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw 'Existing wrangler.local.toml is required. Do not recreate the database or admin credentials.' }
    $text = [IO.File]::ReadAllText($config)
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch '(?m)^binding\s*=\s*"PROFILE_DB"\s*$' -or $text -match '00000000-0000-0000-0000-000000000000') { throw 'Unexpected identity Worker/database config. Nothing deployed.' }
    & node build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing dashboard assets failed to build.' }
    & npx.cmd --yes wrangler@4 d1 execute PROFILE_DB --config $config --remote --file announcement_schema.sql --yes
    if ($LASTEXITCODE -ne 0) { throw 'Announcement schema deployment failed; existing player and mail records are preserved.' }
    & npx.cmd --yes wrangler@4 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Worker deployment failed. The additive announcement schema may already exist; retry this launcher.' }
    Write-Host 'REWARD_ANNOUNCEMENTS_DEPLOY=PASS'
    Write-Host 'Use the existing dashboard username/password. Open Pengumuman to preview and publish.'
    Write-Host 'Re-export Android with this patch. Announcements arrive with the existing mail sync and wait for HOME.'
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { Pop-Location }
