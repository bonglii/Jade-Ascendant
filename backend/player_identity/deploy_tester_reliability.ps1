param([Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $project
try {
    $source=(& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $source -ne $ExpectedCommit) { throw 'Deployment source differs from the reviewed commit.' }
    $backendEdits=@(& git diff HEAD --name-only -- backend)
    if ($LASTEXITCODE -ne 0 -or @($backendEdits | Where-Object { $_ -ne 'backend/monetization/cloudflare/wrangler.production-live.toml' }).Count -gt 0) { throw 'Uncommitted backend edits are preserved. Deploy only the tested backend commit.' }
    & node backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production resource or one of nine gates differs. No deployment attempted.' }
    if ($ValidateOnly) { Write-Host 'TESTER_DEPLOY_PREFLIGHT=PASS; SCHEMA=UNCHANGED; DEPLOY=NONE'; exit 0 }
    $directory=Join-Path $project '.local/tester_reliability_deploy'
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $receiptPath=Join-Path $directory 'receipt.json'
    if (Test-Path -LiteralPath $receiptPath) {
        $receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        if ($receipt.commit -eq $source -and $receipt.worker -eq 'jade-ascendant-iap' -and $receipt.version_id) {
            Write-Host ('TESTER_RESUME_SKIP=deploy; VERSION='+$receipt.version_id)
            exit 0
        }
    }
    # No SQL, secret rotation, new feature gate or schedule modification.
    # Preserve owner variables and all existing Auth/App Check/refund guards.
    $preference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $lines=@(& npx.cmd --yes wrangler@4.151.0 deploy --keep-vars --config backend/monetization/cloudflare/wrangler.production-live.toml 2>&1)
        $code=$LASTEXITCODE
    } finally { $ErrorActionPreference=$preference }
    [IO.File]::WriteAllText((Join-Path $directory 'deploy.log'),($lines -join [Environment]::NewLine))
    $lines | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) { throw ('IAP Worker deployment failed (exit '+$code+'). Completed install/publish/CI stages remain valid; inspect '+(Join-Path $directory 'deploy.log')) }
    $match=[regex]::Match(($lines -join "`n"),'Current Version ID:\s*([a-f0-9-]{36})')
    if (-not $match.Success) { throw 'Deployment returned no version receipt. Inspect deploy.log before retrying.' }
    $body=@{commit=$source;worker='jade-ascendant-iap';version_id=$match.Groups[1].Value;schema='unchanged';native='unchanged';play_products='owner_setup';utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json
    [IO.File]::WriteAllText($receiptPath+'.tmp',$body)
    Move-Item -LiteralPath ($receiptPath+'.tmp') -Destination $receiptPath -Force
    Write-Host 'TESTER_IAP_DEPLOY=PASS; GATES=9; VARS=RETAINED; SCHEMA=UNCHANGED; NATIVE=UNCHANGED; EVENTS=UNCHANGED; PLAY_PRODUCTS=NOT_CREATED'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
