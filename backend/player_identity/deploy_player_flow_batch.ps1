$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$checkpointFolder = Join-Path $repository '.local\player_flow_deploy'
New-Item -ItemType Directory -Force -Path $checkpointFolder | Out-Null
Push-Location $repository
try {
    & node.exe backend/player_identity/production_release_contract.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Existing production release contract failed. No deploy attempted.' }
    & node.exe backend/player_identity/check_player_flow.cjs $repository --server-only
    if ($LASTEXITCODE -ne 0) { throw 'Server regression failed. No deploy attempted.' }
    $profileConfig = Join-Path $PSScriptRoot 'wrangler.local.toml'
    $iapConfig = Join-Path $repository 'backend\monetization\cloudflare\wrangler.production-live.toml'
    if (-not (Test-Path -LiteralPath $profileConfig) -or -not (Test-Path -LiteralPath $iapConfig)) { throw 'Existing live configs are required. No configs or secrets are generated.' }
    $profileText = [IO.File]::ReadAllText($profileConfig)
    $iapText = [IO.File]::ReadAllText($iapConfig)
    if ($profileText -notmatch 'jade-ascendant-player' -or $profileText -notmatch '1089de95-8cdc-447d-a9e3-9e743d200cba') { throw 'Unexpected profile production target.' }
    if ($iapText -notmatch 'jade-ascendant-iap' -or $iapText -notmatch 'f0e59ec4-effb-4002-b9a5-d246965b5b83') { throw 'Unexpected IAP production target.' }
    foreach ($stage in @('profile','iap')) {
        $sourceFolders = @('backend\player_identity')
        if ($stage -eq 'iap') { $sourceFolders = @('backend\monetization\cloudflare\src','backend\monetization\ssv') }
        $parts = @()
        foreach ($sourceFolder in $sourceFolders) {
            $parts += @(Get-ChildItem -LiteralPath (Join-Path $repository $sourceFolder) -File -Recurse | Where-Object { $_.Extension -eq '.mjs' } | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash })
        }
        $config = $profileConfig
        if ($stage -eq 'iap') { $config = $iapConfig }
        $parts += (Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash
        $algorithm = [Security.Cryptography.SHA256]::Create()
        try { $fingerprint = [BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes(($parts -join "`n")))).Replace('-','').ToLowerInvariant() } finally { $algorithm.Dispose() }
        $receipt = Join-Path $checkpointFolder ($stage + '-' + $fingerprint + '.done')
        if (Test-Path -LiteralPath $receipt) { Write-Host ('PLAYER_FLOW_DEPLOY_SKIP=' + $stage); continue }
        & npx.cmd --yes wrangler@4.151.0 deploy --config $config --keep-vars
        if ($LASTEXITCODE -ne 0) { throw ($stage + ' Worker deploy failed. Rerun this command; finished stages are retained.') }
        [IO.File]::WriteAllText($receipt, [DateTime]::UtcNow.ToString('o'))
    }
    Write-Host 'PLAYER_FLOW_DEPLOY=PASS; SCHEMA=UNCHANGED; PAYMENT_GATES=UNCHANGED; EVENT_SCHEDULE=UNCHANGED; BROADCAST=NONE'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { Pop-Location }
