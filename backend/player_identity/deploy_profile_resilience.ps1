$ErrorActionPreference = 'Stop'
Push-Location (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
try {
    $config = Join-Path $PSScriptRoot 'wrangler.local.toml'
    if (-not (Test-Path -LiteralPath $config)) { throw 'Existing wrangler.local.toml is required. No database was created or changed.' }
    $text = Get-Content -Raw -LiteralPath $config
    if ($text -notmatch '(?m)^name\s*=\s*"jade-ascendant-player"\s*$' -or $text -notmatch 'jade-player-identities' -or $text -match '00000000-0000-0000-0000-000000000000') { throw 'Unexpected player worker/database config. Deployment stopped.' }
    & node --test backend/player_identity/identity.test.mjs backend/monetization/cloudflare/tests/auth_runtime_resilience.test.mjs backend/monetization/cloudflare/tests/jwt_verify.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Authentication tests failed. Nothing deployed.' }
    & npx --yes wrangler@4 deploy --config $config
    if ($LASTEXITCODE -ne 0) { throw 'Profile deployment failed.' }
    Write-Host 'PROFILE_RESILIENCE_DEPLOY=PASS; DATABASE_MIGRATION=NONE'
    Write-Host 'Only player identity/mail/banner worker updated. IAP staging worker requires its existing separate deployment procedure.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
