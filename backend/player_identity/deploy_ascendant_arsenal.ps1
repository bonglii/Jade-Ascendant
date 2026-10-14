$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'deploy_ascendant_arsenal.ps1'), [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw 'PowerShell syntax failed; nothing deployed.' }
    & node --test announcements.test.mjs identity.test.mjs mail.test.mjs pavilion.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Server regression failed; nothing deployed.' }
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw 'Existing wrangler.local.toml is required; preserve your existing server config and credentials.' }
    $text = [IO.File]::ReadAllText($config)
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch '(?m)^binding\s*=\s*"PROFILE_DB"\s*$' -or $text -match '00000000-0000-0000-0000-000000000000') { throw 'Unexpected Worker/database config; nothing deployed.' }
    & node build_mail_assets.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Dashboard icon build failed; nothing deployed.' }
    & npx.cmd --yes wrangler@4 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Worker deployment failed; retry this launcher after checking the connection.' }
    Write-Host 'ASCENDANT_ARSENAL_DEPLOY=PASS'
    Write-Host 'Existing dashboard login works. New items can be mailed; new Legendary items can be featured in Pavilion.'
    Write-Host 'Re-export Android with this patch. Older clients safely hide unsupported item mail and banner targets.'
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { Pop-Location }
