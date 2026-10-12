param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($scriptName in @('deploy_mail.ps1','open_mail_dashboard.ps1','publish.ps1','reset_mail_admin.ps1')) {
        $parseTokens = $null
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $scriptName), [ref]$parseTokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw ('PowerShell parse check failed: ' + $scriptName + ': ' + $parseErrors[0].Message) }
    }
    & node --test identity.test.mjs mail.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Mail server tests failed; deployment stopped.' }
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw 'Deploy the existing player identity service first; wrangler.local.toml is required.' }
    $configText = [IO.File]::ReadAllText($config)
    if ($configText -notmatch '(?m)^\[triggers\]\s*$') {
        [IO.File]::AppendAllText($config, [Environment]::NewLine + '[triggers]' + [Environment]::NewLine + 'crons = ["* * * * *"]' + [Environment]::NewLine)
    } elseif ($configText -notmatch '(?m)^crons\s*=\s*\["\* \* \* \* \*"\]\s*$') { throw 'Unexpected existing cron configuration; preserve it and review before deployment.' }
    Add-Type -AssemblyName System.Security
    $protectedKey = Join-Path $PSScriptRoot '.mail-admin-key.dpapi'
    if (Test-Path -LiteralPath $protectedKey) {
        $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($protectedKey), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $adminKey = [Text.Encoding]::UTF8.GetString($bytes)
        if ($adminKey -notmatch '^[a-f0-9]{64}$') { throw 'Invalid local admin key. Preserve the file and investigate; do not silently replace credentials.' }
    } else {
        $bytes = New-Object byte[] 32
        $random = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $random.GetBytes($bytes) } finally { $random.Dispose() }
        $adminKey = -join ($bytes | ForEach-Object { $_.ToString('x2') })
        $encrypted = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($adminKey), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes($protectedKey, $encrypted)
    }
    & npx.cmd --yes wrangler@4 d1 execute PROFILE_DB --config $config --remote --file mail_schema.sql --yes
    if ($LASTEXITCODE -ne 0) { throw 'Mail schema deployment failed.' }
    & npx.cmd --yes wrangler@4 d1 execute PROFILE_DB --config $config --remote --file mail_studio_schema.sql --yes
    if ($LASTEXITCODE -ne 0) { throw 'Studio extension schema deployment failed.' }
    $adminKey | & npx.cmd --yes wrangler@4 secret put MAIL_ADMIN_SECRET --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Mail admin secret installation failed.' }
    $adminKey = $null
    & npx.cmd --yes wrangler@4 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Mail Worker deployment failed.' }
    $client = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts\managers\player_identity_server_client.gd'))
    $match = [regex]::Match($client, 'const ENDPOINT: String = "(https://[^"\r\n]+)/v1/player/register"')
    if (-not $match.Success) { throw 'Client endpoint not found.' }
    Write-Host 'MAIL_SERVER_DEPLOY=PASS'
    Write-Host ('ADMIN_DASHBOARD_URL=' + $match.Groups[1].Value + '/admin')
    Write-Host 'Next: run backend\player_identity\open_mail_dashboard.ps1. Re-export Android once for ServerMailManager.'
} finally {
    $adminKey = $null
    Pop-Location
}
