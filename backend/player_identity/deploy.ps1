param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & node --test (Join-Path $PSScriptRoot 'identity.test.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Player server tests failed; deployment stopped.' }
    # Uses the user's Wrangler login. No credentials are printed or written.
    & npx --yes wrangler@4 whoami
    if ($LASTEXITCODE -ne 0) { throw 'Cloudflare login required: run npx wrangler@4 login, then rerun this script.' }
    $listing = & npx --yes wrangler@4 d1 list --json
    if ($LASTEXITCODE -ne 0) { throw 'Unable to list player databases. Run npx wrangler@4 login locally, then retry.' }
    $databases = ($listing -join "`n") | ConvertFrom-Json
    $database = @($databases | Where-Object { $_.name -eq 'jade-player-identities' })
    if ($database.Count -eq 0) {
        & npx --yes wrangler@4 d1 create jade-player-identities --location apac --update-config=false
        if ($LASTEXITCODE -ne 0) { throw 'Player database creation failed.' }
        $listing = & npx --yes wrangler@4 d1 list --json
        if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve newly created database.' }
        $database = @( (($listing -join "`n") | ConvertFrom-Json) | Where-Object { $_.name -eq 'jade-player-identities' })
    }
    if ($database.Count -ne 1 -or $database[0].uuid -notmatch '^[a-fA-F0-9-]{36}$') { throw 'Ambiguous or invalid player database.' }
    $config = (Get-Content -Raw -LiteralPath 'wrangler.toml').Replace('00000000-0000-0000-0000-000000000000', [string]$database[0].uuid)
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'wrangler.local.toml'), $config, (New-Object Text.UTF8Encoding($false)))
    & npx --yes wrangler@4 d1 execute PROFILE_DB --config wrangler.local.toml --remote --file schema.sql --yes
    if ($LASTEXITCODE -ne 0) { throw 'Player schema deployment failed.' }
    $deployment = & npx --yes wrangler@4 deploy --config wrangler.local.toml
    if ($LASTEXITCODE -ne 0) { throw 'Player worker deployment failed.' }
    $deployment | ForEach-Object { Write-Host $_ }
    $match = [regex]::Match(($deployment -join "`n"), 'https://jade-ascendant-player\.[a-z0-9-]+\.workers\.dev')
    if (-not $match.Success) { throw 'Worker URL not found; client endpoint was not changed.' }
    $url = $match.Value
    $health = Invoke-RestMethod -Uri ($url + '/health') -Method Get
    if ($health.service -ne 'jade-player-identity' -or -not $health.ready) { throw 'Player service health check failed.' }
    $client = Join-Path $RepositoryRoot 'scripts\managers\player_identity_server_client.gd'
    $source = Get-Content -Raw -LiteralPath $client
    $source = [regex]::Replace($source, 'const ENDPOINT: String = "https://[^"\r\n]+/v1/player/register"', ('const ENDPOINT: String = "' + $url + '/v1/player/register"'))
    [IO.File]::WriteAllText($client, $source, (New-Object Text.UTF8Encoding($false)))
    Write-Host ('PLAYER_SERVER_DEPLOY=PASS; URL=' + $url)
    Write-Host 'Re-export Android with the patched client. Verify Profile shows SERVER CONNECTED and a 12-character UID.'
} finally { Pop-Location }
