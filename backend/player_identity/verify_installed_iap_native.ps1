$ErrorActionPreference = 'Stop'
try {
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    # Reuse the input-inventory verifier already exercised by Windows CI.
    # Parsing definitions does not run the network/device diagnostic body.
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'check_account_iap.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count -ne 0) { throw 'Native input checker cannot be parsed.' }
    foreach ($name in @('Get-JadeNativeTextHash','Test-JadeNativeInputs')) {
        $definition = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
        if ($null -eq $definition) { throw ('Missing native verifier: ' + $name) }
        Invoke-Expression $definition.Extent.Text
    }
    $meta = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $repo 'docs/checkpoints/IAP_CLIENT_V2_NATIVE.json')))
    if ($meta.native_contract -ne 'PASS' -or -not (Test-JadeNativeInputs $meta)) { throw 'Installed native receipt does not match all current compile inputs.' }
    foreach ($variant in @('debug','release')) {
        $entry = $null; $count = 0
        foreach ($item in $meta.artifacts) { if ($item.variant -eq $variant) { $entry = $item; $count++ } }
        $expected = 'locked'; if ($variant -eq 'debug') { $expected = 'staging' }
        if ($count -ne 1 -or $entry.target -ne $expected) { throw ('Invalid native target receipt: ' + $variant) }
        $path = Join-Path $repo ('addons/JadeMonetizationNativeBridge/bin/' + $variant + '/JadeMonetizationNativeBridge-' + $variant + '.aar')
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw ('Native binary differs from verified receipt: ' + $variant) }
        Write-Host ('NATIVE_' + $variant.ToUpperInvariant() + '_BRIDGE_SOURCE_MATCH=True; TARGET=' + $expected)
    }
    Write-Host 'INSTALLED_IAP_NATIVE=VERIFIED; PRODUCTION_RELEASE=LOCKED; NETWORK=NONE; PURCHASE=NONE'
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
