param([ValidateSet('baseline','account-b','back-to-a','after-refund')][string]$Label = 'baseline')
$ErrorActionPreference = 'Stop'
try {
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $ps = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $out = Join-Path $repo ('.local/iap_lifecycle/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + $Label + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    Write-Host ('IAP_LIFECYCLE=READ_ONLY_STAGING; LABEL=' + $Label + '; PURCHASE=NONE; DEPLOY=NONE')
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'diagnose_iap_delivery.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Ledger diagnosis failed; no successful evidence recorded.' }
    Copy-Item -LiteralPath (Join-Path $repo '.local/iap_delivery/diagnosis-latest.json') -Destination (Join-Path $out 'ledger.json')
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check_account_iap.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Device readiness collection failed; ledger evidence retained.' }
    $support = Join-Path ([IO.Path]::GetTempPath()) 'Jade-Account-IAP-Readiness.txt'
    if (Test-Path -LiteralPath $support) { Copy-Item -LiteralPath $support -Destination (Join-Path $out 'readiness.txt') }
    Write-Host ('LIFECYCLE_REPORT=' + $out)
    Write-Host 'Labels describe the collection step, not proof that account switch/refund or Play Integrity passed. Include in-game Copy support.'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
