$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$t=$null;$e=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'backend/player_identity/check_account_iap.ps1'),[ref]$t,[ref]$e)
if ($e.Count) { throw 'Native checker parse failed' }
foreach ($name in @('Get-JadeNativeTextHash','Test-JadeNativeInputs')) {
    $definition=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    Invoke-Expression $definition.Extent.Text
}
$meta=Get-Content -Raw (Join-Path $repo 'docs/checkpoints/IAP_DELIVERY_NATIVE.json') | ConvertFrom-Json
if (-not (Test-JadeNativeInputs $meta)) {throw 'Matching native inputs rejected'}
$key='backend/monetization/android_bridge/bridge/src/main/java/com/yungdevstudio/jadeascendant/monetizationbridge/TrustedIapHttps.kt'
$meta.inputs.PSObject.Properties[$key].Value='0'*64
if (Test-JadeNativeInputs $meta) {throw 'Stale DNS source was accepted'}
$meta.inputs=$null
if (Test-JadeNativeInputs $meta) {throw 'Missing build inputs accepted'}
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('jade-provenance-'+[Guid]::NewGuid().ToString('N'))
try {
    [IO.File]::WriteAllText($fixture,"line one`nline two`n")
    $before=Get-JadeNativeTextHash $fixture
    [IO.File]::WriteAllText($fixture,"line one`r`nline two`r`n")
    if ($before -ne (Get-JadeNativeTextHash $fixture)) {throw 'CRLF normalization mismatch'}
    [IO.File]::WriteAllText($fixture,"line changed`nline two`n")
    if ($before -eq (Get-JadeNativeTextHash $fixture)) {throw 'Changed source accepted as same'}
} finally {Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue}
Write-Host 'NATIVE_PROVENANCE=PASS; CHECKS=5'
