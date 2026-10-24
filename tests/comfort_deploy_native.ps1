param([string]$Project=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$engine=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$source=Join-Path $Project 'backend/player_identity/deploy_release_comfort.ps1'
$tokens=$null; $parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('Jade Native Stderr '+[Guid]::NewGuid().ToString('N'))
$bin=Join-Path $fixture 'bin';New-Item -ItemType Directory -Force -Path $bin | Out-Null
$originalPath=$env:PATH
$names=@('JADE_NATIVE_FIX_CALLS','JADE_NATIVE_FIX_SCHEMA_EXIT','JADE_NATIVE_FIX_DEPLOY_EXIT','JADE_NATIVE_FIX_NO_VERSION')
$original=@{};foreach($name in $names){$original[$name]=[Environment]::GetEnvironmentVariable($name)}
$encoding=New-Object Text.UTF8Encoding($false)
$commit='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$checks=0
function Assert-Case([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message};$script:checks++}
function Write-Fixture([string]$File,[string]$Text){[IO.File]::WriteAllText($File,$Text.Replace("`r`n","`n").Replace("`n","`r`n"),$encoding)}
try {
 Write-Fixture (Join-Path $bin 'git.cmd') @'
@echo off
if "%1"=="branch" echo checkpoint/iap-fasttrack-20261010
if "%1"=="rev-parse" echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
exit /b 0
'@
 Write-Fixture (Join-Path $bin 'node.cmd') "@echo off`nexit /b 0`n"
 Write-Fixture (Join-Path $bin 'npx.cmd') @'
@echo off
echo %3>>"%JADE_NATIVE_FIX_CALLS%"
echo WARNING: D1 import may temporarily pause queries 1>&2
if "%3"=="d1" exit /b %JADE_NATIVE_FIX_SCHEMA_EXIT%
if not "%JADE_NATIVE_FIX_NO_VERSION%"=="1" echo Current Version ID: 00000000-0000-4000-8000-000000000001
exit /b %JADE_NATIVE_FIX_DEPLOY_EXIT%
'@
 $env:PATH=$bin+';'+$originalPath
 function Run-Case([string]$Name,[int]$SchemaExit=0,[int]$DeployExit=0,[bool]$NoVersion=$false,[switch]$ValidateOnly,[switch]$WrongWorker){
  $root=Join-Path $fixture $Name;$backend=Join-Path $root 'backend/player_identity'
  New-Item -ItemType Directory -Force -Path $backend | Out-Null
  Copy-Item -LiteralPath $source -Destination (Join-Path $backend 'deploy_release_comfort.ps1')
  $worker=if($WrongWorker){'wrong-worker'}else{'jade-ascendant-player'}
  Write-Fixture (Join-Path $backend 'wrangler.local.toml') ('name = "'+$worker+'"'+"`n"+'main = "worker.mjs"'+"`n"+'database_id = "1089de95-8cdc-447d-a9e3-9e743d200cba"')
  $env:JADE_NATIVE_FIX_CALLS=Join-Path $root 'native-calls.txt'
  $env:JADE_NATIVE_FIX_SCHEMA_EXIT=[string]$SchemaExit;$env:JADE_NATIVE_FIX_DEPLOY_EXIT=[string]$DeployExit;$env:JADE_NATIVE_FIX_NO_VERSION=if($NoVersion){'1'}else{'0'}
  $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $backend 'deploy_release_comfort.ps1'),'-ExpectedCommit',$commit)
  if($ValidateOnly){$arguments+='-ValidateOnly'}
  $previous=$ErrorActionPreference
  try{$ErrorActionPreference='Continue';$lines=@(& $engine @arguments 2>&1);$exit=$LASTEXITCODE}finally{$ErrorActionPreference=$previous}
  $receipt=Join-Path $root '.local/release_comfort_deploy/receipt.json'
  $calls=@();if(Test-Path -LiteralPath $env:JADE_NATIVE_FIX_CALLS){$calls=@(Get-Content -LiteralPath $env:JADE_NATIVE_FIX_CALLS)}
  return [pscustomobject]@{Root=$root;Code=$exit;Lines=($lines -join "`n");Receipt=$receipt;Calls=$calls}
 }
 $ok=Run-Case 'warning-success'
 Assert-Case ($ok.Code -eq 0) ('Harmless stderr warning must pass: '+$ok.Lines)
 Assert-Case ((Test-Path -LiteralPath $ok.Receipt) -and $ok.Calls.Count -eq 2) 'Real exit0 and version receipt required'
 Assert-Case ($ok.Lines.Contains('WARNING:') -and $ok.Lines.Contains('COMFORT_PROFILE_DEPLOY=PASS')) 'Warning is retained in successful output'
 $again=Run-Case 'warning-success'
 Assert-Case ($again.Code -eq 0 -and $again.Calls.Count -eq 2 -and $again.Lines.Contains('RESUME_SKIP')) 'Successful receipt skips repeated schema/deploy'
 $bad=Run-Case 'schema-failure' 7
 Assert-Case ($bad.Code -ne 0 -and $bad.Calls.Count -eq 1 -and -not (Test-Path -LiteralPath $bad.Receipt)) 'Schema exit7 must stop before Worker deployment'
 Assert-Case (Test-Path -LiteralPath (Join-Path $bad.Root '.local/release_comfort_deploy/schema.log')) 'Failed schema preserves stderr diagnostics'
 $retry=Run-Case 'schema-failure'
 Assert-Case ($retry.Code -eq 0 -and $retry.Calls.Count -eq 3) 'Failed schema is safely retryable; prior stages are not rerun'
 $deploy=Run-Case 'deploy-failure' 0 9
 Assert-Case ($deploy.Code -ne 0 -and -not (Test-Path -LiteralPath $deploy.Receipt)) 'Worker exit9 cannot create a success receipt'
 $missing=Run-Case 'missing-version' 0 0 $true
 Assert-Case ($missing.Code -ne 0 -and -not (Test-Path -LiteralPath $missing.Receipt)) 'Exit0 without actual version receipt cannot claim deployment'
 $dry=Run-Case 'validate-only' -ValidateOnly
 Assert-Case ($dry.Code -eq 0 -and $dry.Calls.Count -eq 0) 'ValidateOnly invokes no Wrangler command'
 $wrong=Run-Case 'wrong-worker' -WrongWorker
 Assert-Case ($wrong.Code -ne 0 -and $wrong.Calls.Count -eq 0) 'Wrong worker is rejected before native invocation'
 Write-Host ('COMFORT_NATIVE_FIX_FIXTURE=PASS; CHECKS='+$checks+'; WRANGLER=STUBBED; REAL_DEPLOY=NONE')
} finally {
 $env:PATH=$originalPath
 foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$original[$name])}
 if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
exit 0
