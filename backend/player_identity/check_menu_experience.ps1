param(
    [string]$Project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
$encoding = New-Object Text.UTF8Encoding($false)
function Quote-QAArgument([string]$Value) {
    $result='"';$slashes=0
    foreach($letter in $Value.ToCharArray()) {
        if($letter -eq [char]92){$slashes++;continue}
        if($letter -eq [char]34){$result+=('\'*($slashes*2+1))+'"';$slashes=0;continue}
        $result+=('\'*$slashes)+$letter;$slashes=0
    }
    return $result+('\'*($slashes*2))+'"'
}
function Invoke-QAProcess([string]$Executable,[string[]]$Arguments,[string]$DataRoot,[string]$LogName) {
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Executable;$info.WorkingDirectory=$repo;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=$encoding;$info.StandardErrorEncoding=$encoding
    $info.Arguments=(($Arguments|ForEach-Object{Quote-QAArgument $_})-join ' ')
    if($DataRoot){[IO.Directory]::CreateDirectory($DataRoot)|Out-Null;$info.EnvironmentVariables['APPDATA']=$DataRoot;$info.EnvironmentVariables['XDG_DATA_HOME']=$DataRoot}
    $process=[Diagnostics.Process]::Start($info)
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(240000)){$process.Kill();throw ('QA timeout: '+$LogName)}
    $text=$stdout.Result+$stderr.Result;$code=$process.ExitCode;$process.Dispose()
    [IO.File]::WriteAllText((Join-Path $qaRoot ($LogName+'.log')),$text,$encoding)
    if($code -ne 0 -or $text -match '(?m)^(SCRIPT ERROR:|ERROR:)'){throw ('QA failed: '+$LogName+'. Logs retained at '+$qaRoot)}
    return $text
}
try {
    $repo=(Resolve-Path -LiteralPath $Project).Path
    $qaRoot=Join-Path ([IO.Path]::GetTempPath()) ('Jade-Menu-Experience-QA-'+[Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($qaRoot)|Out-Null
    $psBinary=(Get-Process -Id $PID).Path
    $native=Invoke-QAProcess $psBinary @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repo 'backend/player_identity/export_production.ps1'),'-Project',$repo,'-VerifyOnly') '' 'native-preflight'
    if($native -notmatch 'PRODUCTION_EXPORT_PREFLIGHT=PASS'){throw 'Matching native preflight receipt was not returned.'}
    if(-not $GodotPath){
        $remembered=Join-Path $repo '.local/production_native_export/godot-path.local.txt'
        if(Test-Path -LiteralPath $remembered){$GodotPath=[IO.File]::ReadAllText($remembered).Trim()}
    }
    if(-not $GodotPath){
        $command=Get-Command godot -ErrorAction SilentlyContinue
        if($command){$GodotPath=$command.Source}
    }
    if(-not $GodotPath){
        foreach($folder in @('D:\Godot','D:\Godot\tools')){
            if(-not(Test-Path -LiteralPath $folder)){continue}
            $matches=@(Get-ChildItem -LiteralPath $folder -File -Filter '*console.exe'|Where-Object{$_.Name -match '^Godot.*4\.7\.2'})
            if($matches.Count -eq 1){$GodotPath=$matches[0].FullName;break}
        }
    }
    if(-not $GodotPath -or -not(Test-Path -LiteralPath $GodotPath -PathType Leaf)){throw 'Godot 4.7.2 console executable not found. Pass -GodotPath; source is retained.'}
    $version=Invoke-QAProcess $GodotPath @('--version') '' 'engine-version'
    if($version -notmatch '^4\.7\.2\.stable\.'){throw ('Expected Godot 4.7.2 stable, got: '+$version.Trim())}
    $qaData=Join-Path $qaRoot 'jade_paid_v2_qa_import'
    $null=Invoke-QAProcess $GodotPath @('--headless','--path',$repo,'--audio-driver','Dummy','--rendering-method','gl_compatibility','--editor','--import','--quit') $qaData 'import'
    $steps=@(
        @{name='menu';script='menu_experience_smoke.gd';data='jade_paid_v2_qa_menu';headless=$true;extra=@()},
        @{name='content';script='player_content_batch_smoke.gd';data='jade_paid_v2_qa_content';headless=$true;extra=@()},
        @{name='trials';script='menu_weekly_gui_smoke.gd';data='jade_heavenly_trials_qa_content';headless=$false;extra=@()},
        @{name='clarity';script='combat_clarity_smoke.gd';data='jade_event_touch_qa_clarity';headless=$true;extra=@()},
        @{name='clarity-resume';script='combat_clarity_smoke.gd';data='jade_event_touch_qa_clarity';headless=$true;extra=@('--','--resume')},
        @{name='direction';script='player_direction_smoke.gd';data='jade_event_touch_qa_direction';headless=$false;extra=@()}
    )
    $summary=New-Object Collections.Generic.List[object]
    foreach($step in $steps){
        Write-Host ('MENU_EXPERIENCE_QA_STEP='+$step.name)
        $arguments=@('--path',$repo,'--audio-driver','Dummy','--rendering-method','gl_compatibility','--script',('res://tests/'+$step.script))
        if($step.headless){$arguments=@('--headless')+$arguments}
        $arguments+=$step.extra
        $text=Invoke-QAProcess $GodotPath $arguments (Join-Path $qaRoot $step.data) $step.name
        $lines=@($text -split "`n"|Where-Object{$_ -match 'checks=.*failures=0'})
        if($lines.Count -lt 1){throw ('No successful assertion receipt: '+$step.name)}
        foreach($line in $lines){Write-Host $line.Trim()}
        $summary.Add(@{step=$step.name;result='PASS';receipts=$lines})
    }
    $result=@{batch='MENU_PLAYER_EXPERIENCE_20261103';host=[Environment]::OSVersion.Platform.ToString();native='MATCHING_52_INPUTS';checks=$summary.ToArray();owner_saves='NOT_USED';deploy='NOT_RUN';aab='NOT_EXPORTED';phone='UNCONFIRMED'}
    [IO.File]::WriteAllText((Join-Path $qaRoot 'QA_RESULT.json'),($result|ConvertTo-Json -Depth 8),$encoding)
    Write-Host ('MENU_EXPERIENCE_QA=PASS; HOST='+$result.host+'; RESULTS='+$qaRoot)
    exit 0
}catch{
    Write-Error $_ -ErrorAction Continue
    Write-Host ('MENU_EXPERIENCE_QA=FAILED; RESULTS='+$qaRoot+'; OWNER_SAVES=NOT_USED')
    exit 1
}
