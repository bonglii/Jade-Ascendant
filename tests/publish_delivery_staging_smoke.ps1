$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\backend\player_identity\publish_delivery_motion.ps1'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Publisher has syntax errors.' }
$definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stage-JadePackage' }, $true)
if ($null -eq $definition) { throw 'Staging function missing.' }
Invoke-Expression $definition.Extent.Text
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('jade-publish-stage-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$checks = 0
function Assert-Stage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }; $script:checks++
}
Push-Location $fixture
try {
    & git init -q
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize isolated fixture.' }
    [IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "*.aar`n*.import`nignored-source.gd`n")
    [IO.File]::WriteAllText((Join-Path $fixture 'tracked.gd'), 'original')
    & git add -- tracked.gd
    if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare tracked fixture.' }
    [IO.File]::WriteAllText((Join-Path $fixture 'tracked.gd'), 'updated')
    $asset = 'assets/ui/motion/poster.webp.import'
    New-Item -ItemType Directory -Force -Path (Split-Path $asset) | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixture $asset), 'import fixture')
    $aar = 'addons/JadeMonetizationNativeBridge/bin/debug/JadeMonetizationNativeBridge-debug.aar'
    New-Item -ItemType Directory -Force -Path (Split-Path $aar) | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixture $aar), 'binary fixture')
    [IO.File]::WriteAllText((Join-Path $fixture 'unrelated.txt'), 'leave alone')
    Stage-JadePackage -AllowedPaths @('tracked.gd', $asset, $aar)
    $staged = @(& git diff --cached --name-only)
    Assert-Stage ($staged.Count -eq 3 -and $staged -contains $asset -and $staged -contains $aar) 'Ignored approved assets were not staged.'
    Assert-Stage ($staged -notcontains 'unrelated.txt' -and $staged -notcontains '.gitignore') 'Unrelated file was staged.'
    Stage-JadePackage -AllowedPaths @('tracked.gd', $asset, $aar)
    Assert-Stage ($LASTEXITCODE -eq 0) 'Repeated staging failed.'
    [IO.File]::WriteAllText((Join-Path $fixture 'ignored-source.gd'), 'must not force')
    $blocked = $false
    try { Stage-JadePackage -AllowedPaths @('ignored-source.gd') } catch { $blocked = $_.Exception.Message.Contains('no forced staging') }
    Assert-Stage $blocked 'Ignored source was forced into Git.'
    $blocked = $false
    try { Stage-JadePackage -AllowedPaths @('../outside.txt') } catch { $blocked = $_.Exception.Message.Contains('Unsafe package path') }
    Assert-Stage $blocked 'Traversal path was accepted.'
    [IO.File]::WriteAllText((Join-Path $fixture '.git/index.lock'), 'fixture lock')
    $diagnostic = ''
    try { Stage-JadePackage -AllowedPaths @('tracked.gd') } catch { $diagnostic = $_.Exception.Message }
    Assert-Stage ($diagnostic.Contains('tracked.gd') -and $diagnostic.Contains('index.lock')) 'Git failure lost file or original lock diagnostic.'
    Write-Host ('DELIVERY_PUBLISH_STAGING=PASS; CHECKS=' + $checks)
} finally {
    Pop-Location
    Remove-Item -LiteralPath $fixture -Recurse -Force
}

# Intentional negative Git tests leave LASTEXITCODE=1. The assertions above
# decide success; GitHub must not inherit that expected failure as job failure.
exit 0
