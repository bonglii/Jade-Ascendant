$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$checks = 0
foreach ($path in @('backend/player_identity/build_iap_production_candidate.ps1','backend/player_identity/build_native_bridge.ps1','backend/player_identity/collect_iap_lifecycle.ps1','backend/player_identity/configure_iap_second_tester.ps1','backend/player_identity/publish_iap_lifecycle.ps1')) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $path),[ref]$tokens,[ref]$errors)
    if ($errors.Count -ne 0) { throw ('PowerShell parse failure: ' + $path + ': ' + ($errors -join '; ')) }
    $checks++
}
Write-Host ('IAP_CANDIDATE_LAUNCHERS_PARSE=PASS; CHECKS=' + $checks)
