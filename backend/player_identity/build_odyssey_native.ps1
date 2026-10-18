param([string]$SdkRoot='D:\SDK',[string]$GradlePath='')
$ErrorActionPreference='Stop'
$oldJava=$env:JAVA_HOME
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
try {
    if (Test-Path -LiteralPath (Join-Path $repo '.local/production_native_export/active.json')) { throw 'Interrupted export exists. Run recover_production_export.cmd before rebuilding.' }
    if (-not $env:JAVA_HOME -or -not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin/javap.exe'))) {
        $javac=(Get-Command javac.exe -ErrorAction Stop).Source
        $env:JAVA_HOME=Split-Path (Split-Path $javac -Parent) -Parent
    }
    . (Join-Path $PSScriptRoot 'gradle813_bootstrap.ps1')
    $GradlePath=Get-JadeGradle813 -GradlePath $GradlePath
    & (Join-Path $PSScriptRoot 'build_iap_production_candidate.ps1') -SdkRoot $SdkRoot -GradlePath $GradlePath
    if ($LASTEXITCODE -ne 0) { throw 'Production native build failed. Existing artifacts retained.' }
    $parent=Join-Path $repo '.local/production_native_candidate'
    $latest=@(Get-ChildItem -LiteralPath $parent -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'receipt.json') } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
    if ($latest.Count -ne 1) { throw 'Build receipt not found.' }
    & node (Join-Path $PSScriptRoot 'finalize_odyssey_native.cjs') $latest[0].FullName
    if ($LASTEXITCODE -ne 0) { throw 'Native verification failed. No publish attempted.' }
} catch { Write-Error $_ -ErrorAction Continue; exit 1 } finally { $env:JAVA_HOME=$oldJava }
