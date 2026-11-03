param(
    [string]$ProjectPath='D:\Godot\project\jade-ascendant',
    [ValidateSet('Audit','Apply','Restore')][string]$Mode='Audit',
    [string]$PackageRoot=$PSScriptRoot,
    [string]$ReceiptPath=''
)
$ErrorActionPreference='Stop'
$utf8=New-Object Text.UTF8Encoding($false,$true)
function Hash-Bytes([byte[]]$Bytes){
    $h=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}
}
function Read-Canonical([string]$Path){
    $s=$utf8.GetString([IO.File]::ReadAllBytes($Path))
    if($s.Length -gt 0 -and $s[0] -eq [char]0xfeff){$s=$s.Substring(1)}
    return $s.Replace("`r`n","`n")
}
function Text-Hash([string]$Path){return Hash-Bytes ($utf8.GetBytes((Read-Canonical $Path)))}
function Plain-Path([string]$Path){
    $p=[IO.Path]::GetFullPath($Path)
    while($p){
        if((Test-Path -LiteralPath $p) -and (([IO.File]::GetAttributes($p) -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw ('Link/reparse point refused: '+$Path)}
        $parent=[IO.Path]::GetDirectoryName($p);if($parent -eq $p){break};$p=$parent
    }
}
function Target([string]$Relative){
    if(-not $Relative -or $Relative.StartsWith('/') -or $Relative.Contains('\') -or $Relative.Contains(':') -or @($Relative.Split('/')|Where-Object{$_ -eq '.' -or $_ -eq '..'}).Count){throw 'Unsafe manifest path'}
    $path=Join-Path $project $Relative;Plain-Path $path;return $path
}
function Git-Paths([string[]]$Arguments){
    $raw=& $git -C $project ls-files -z @Arguments
    if($LASTEXITCODE -ne 0){throw 'Git inventory failed'}
    return @(([string]::Join("`n",@($raw))).Split([char]0)|Where-Object{$_})
}
function Write-Atomic([string]$Path, [byte[]]$Bytes) {
    Plain-Path $Path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $temporary = $Path + '.jade-content-' + [Guid]::NewGuid().ToString('N') + '.tmp'
    $prior = $Path + '.jade-prior-' + [Guid]::NewGuid().ToString('N') + '.bak'
    $replaced = $false
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary, $Path, $prior); $replaced = $true }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) }
        if ($replaced -and (Test-Path -LiteralPath $prior)) { [IO.File]::Delete($prior) }
    }
}
function Preserve-Text([string]$Canonical,[byte[]]$Before){
    $old=$utf8.GetString($Before);$s=$Canonical
    if($old.Contains("`r`n")){$s=$s.Replace("`n","`r`n")}
    if($old.Length -gt 0 -and $old[0] -eq [char]0xfeff){$s=([string][char]0xfeff)+$s}
    return ,$utf8.GetBytes($s)
}
$written=New-Object Collections.Generic.List[object]
$success=$false
try{
    $project=(Resolve-Path -LiteralPath $ProjectPath).Path;Plain-Path $project
    $package=(Resolve-Path -LiteralPath $PackageRoot).Path;Plain-Path $package
    $git=(Get-Command git -ErrorAction Stop).Source
    $top=(& $git -C $project rev-parse --show-toplevel).Trim()
    if($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($top).TrimEnd([char]47,[char]92) -ne [IO.Path]::GetFullPath($project).TrimEnd([char]47,[char]92)){throw 'Project must be the Git root'}
    $manifest=Get-Content -LiteralPath (Join-Path $package 'cleanup_manifest.json') -Raw|ConvertFrom-Json
    if($manifest.batch -ne 'REPOSITORY_CLEANUP_20261103'){throw 'Wrong cleanup manifest'}
    $tracked=Git-Paths @();$untracked=Git-Paths @('--others','--exclude-standard')
    $activeExport=Test-Path -LiteralPath (Join-Path $project '.local/production_native_export/active.json')
    if($Mode -ne 'Audit'){
        $branch=(& $git -C $project branch --show-current).Trim()
        if($branch -in @('main','master','production')){throw 'Use the authorized work branch'}
        if($activeExport){throw 'Exporter recovery is active; wait for the existing exporter to restore its bridge'}
        if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){
            if(@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count){throw 'Close Godot and let any exporter recovery finish before cleanup'}
        }
    }
    if($Mode -eq 'Restore'){
        if(-not $ReceiptPath){throw 'Pass the exact APPLY_RECEIPT.json path printed after cleanup'}
        $receiptFile=(Resolve-Path -LiteralPath $ReceiptPath).Path;Plain-Path $receiptFile
        $receipt=Get-Content -LiteralPath $receiptFile -Raw|ConvertFrom-Json
        if($receipt.batch -ne $manifest.batch -or $receipt.project -ne $project){throw 'Restore receipt belongs to another project/batch'}
        $session=Split-Path -Parent $receiptFile;$restore=New-Object Collections.Generic.List[object]
        foreach($row in $receipt.files){
            $target=Target $row.path;$backup=Join-Path $session ('original/'+$row.path);Plain-Path $backup
            $bytes=[IO.File]::ReadAllBytes($backup);if((Hash-Bytes $bytes) -ne $row.before_sha256){throw 'Backup hash mismatch'}
            $exists=Test-Path -LiteralPath $target
            $current=if($exists){Hash-Bytes ([IO.File]::ReadAllBytes($target))}else{''}
            if($current -ne $row.before_sha256 -and $current -ne $row.after_sha256){throw ('Concurrent edit retained; restore requires review: '+$row.path)}
            if($current -ne $row.before_sha256){$restore.Add(@{Target=$target;Bytes=$bytes;Existed=$exists;Before=$(if($exists){[IO.File]::ReadAllBytes($target)}else{$null})})}
        }
        # Restore assets before restoring the code that may reference their old paths.
        foreach($row in @($restore|Sort-Object {if($_.Target.EndsWith('.gd')){1}else{0}})){Write-Atomic $row.Target $row.Bytes}
        Write-Host ('REPOSITORY_CLEANUP_RESTORE=PASS; FILES='+$restore.Count);$success=$true;exit 0
    }
    $folders=@{};$files=New-Object Collections.Generic.List[object];$sizes=@{}
    foreach($relative in $tracked){
        $p=Target $relative;if(-not(Test-Path -LiteralPath $p -PathType Leaf)){continue}
        $size=(Get-Item -LiteralPath $p -Force).Length;$first=$relative.Split('/')[0]
        if(-not $folders.ContainsKey($first)){$folders[$first]=@{files=0;bytes=0}}
        $folders[$first].files++;$folders[$first].bytes+=$size
        $row=@{path=$relative;bytes=$size};$files.Add($row)
        $key=[string]$size;if(-not $sizes.ContainsKey($key)){$sizes[$key]=New-Object Collections.Generic.List[object]};$sizes[$key].Add($row)
    }
    $duplicates=New-Object Collections.Generic.List[object]
    foreach($group in $sizes.Values){
        if($group.Count -lt 2 -or $group[0].bytes -eq 0){continue}
        $hashes=@{}
        foreach($row in $group){if([IO.Path]::GetExtension($row.path) -in @('.jks','.keystore','.p12','.pem') -or [IO.Path]::GetFileName($row.path).StartsWith('.env')){continue};$h=Hash-Bytes ([IO.File]::ReadAllBytes((Target $row.path)));if(-not $hashes.ContainsKey($h)){$hashes[$h]=New-Object Collections.Generic.List[string]};$hashes[$h].Add($row.path)}
        foreach($h in $hashes.Keys){if($hashes[$h].Count -gt 1){$duplicates.Add(@{sha256=$h;bytes_each=$group[0].bytes;paths=$hashes[$h].ToArray()})}}
    }
    $proof=Get-Content -LiteralPath (Join-Path $project 'docs/checkpoints/IAP_PRODUCTION_NATIVE_CANDIDATE.json') -Raw|ConvertFrom-Json
    $nativeMismatch=New-Object Collections.Generic.List[string]
    foreach($property in $proof.inputs.PSObject.Properties){if((Text-Hash (Target $property.Name)) -ne $property.Value){$nativeMismatch.Add($property.Name)}}
    $candidate=Target 'release/native/JadeMonetizationNativeBridge-production-candidate.aar'
    $nativeOk=$nativeMismatch.Count -eq 0 -and (Hash-Bytes ([IO.File]::ReadAllBytes($candidate))) -eq $proof.aar_sha256
    $runtimeUnknown=New-Object Collections.Generic.List[string]
    $sourceExtensions=@('.cs','.gd','.tscn','.tres','.gdshader','.gdextension','.cfg','.godot','.json')
    foreach($relative in @($tracked)+@($untracked)){
        if($relative -ne 'project.godot' -and -not($relative.StartsWith('scripts/') -or $relative.StartsWith('scenes/') -or $relative.StartsWith('assets/') -or $relative.StartsWith('addons/'))){continue}
        if([IO.Path]::GetExtension($relative) -notin $sourceExtensions){continue}
        $p=Target $relative;if(-not(Test-Path -LiteralPath $p -PathType Leaf)){continue}
        $rule=$manifest.reference_guard.PSObject.Properties[$relative]
        if($null -eq $rule -or (Text-Hash $p) -notin @($rule.Value)){$runtimeUnknown.Add($relative)}
    }
    $localOnly=New-Object Collections.Generic.List[object]
    $ignoredSummary=@{}
    foreach($relative in $untracked){
        $p=Join-Path $project $relative
        try{
            $info=Get-Item -LiteralPath $p -Force
            $kind='REVIEW_UNTRACKED_DO_NOT_DELETE'
            if($relative -match '(^|/)(backups?|receipts?|recovery)(/|$)' -or $relative -match '\.(jks|keystore|p12|pem|aab|apk)$' -or [IO.Path]::GetFileName($relative).StartsWith('.env')){$kind='KEEP_PROTECTED'}
            elseif($relative -match '\.(tmp|pyc|pyo|swp|swo)$'){$kind='REVIEW_GENERATED_NOT_APPROVED_FOR_REMOVAL'}
            $localOnly.Add(@{path=$relative;bytes=$(if($info -is [IO.FileInfo]){$info.Length}else{0});decision=$kind})
        }catch{$localOnly.Add(@{path=$relative;decision='VANISHED_OR_UNREADABLE_DURING_SCAN'})}
    }
    foreach($relative in (Git-Paths @('--others','--ignored','--exclude-standard'))){
        $first=$relative.Split('/')[0]
        if(-not $ignoredSummary.ContainsKey($first)){$ignoredSummary[$first]=@{files=0;bytes=0;decision='KEEP_IGNORED_CONTENT_NOT_READ'}}
        $ignoredSummary[$first].files++
        try{$info=Get-Item -LiteralPath (Join-Path $project $relative) -Force;if($info -is [IO.FileInfo]){$ignoredSummary[$first].bytes+=$info.Length}}catch{}
    }
    $reportDir=Join-Path $package ('results/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($reportDir)|Out-Null
    $audit=@{batch=$manifest.batch;mode=$Mode;project=$project;tracked_count=$tracked.Count;untracked_count=$untracked.Count;local_only_files=$localOnly.ToArray();ignored_roots_metadata_only=$ignoredSummary;folders=$folders;tracked_files=$files.ToArray();duplicates=$duplicates.ToArray();native_52_inputs_and_candidate_match=$nativeOk;native_mismatches=$nativeMismatch.ToArray();unreviewed_runtime_sources=$runtimeUnknown.ToArray();export_active=$activeExport;protected='Saves/cache/backups/receipt/recovery/build outputs/signing data are not deleted or scanned for content';cleanup='NOT_RUN'}
    [IO.File]::WriteAllText((Join-Path $reportDir 'LOCAL_AUDIT.json'),($audit|ConvertTo-Json -Depth 9),$utf8)
    Write-Host ('LOCAL_AUDIT_REPORT='+$reportDir)
    if($Mode -eq 'Audit'){Write-Host 'REPOSITORY_AUDIT=PASS; SOURCE_WRITES=0; CLEANUP=NOT_RUN';$success=$true;exit 0}
    if(-not $nativeOk){throw 'Native provenance mismatch; zero source writes'}
    if($runtimeUnknown.Count){throw 'Runtime source differs from reviewed snapshot; zero source writes. Retain edits and review LOCAL_AUDIT.json'}
    $plan=New-Object Collections.Generic.List[object]
    foreach($entry in $manifest.updates){
        $target=Target $entry.path;$before=[IO.File]::ReadAllBytes($target);$current=Read-Canonical $target
        if($entry.kind -eq 'append_ignore'){
            $after=$current
            foreach($line in $entry.lines){if(-not $after.Contains([string]$line)){$after+="`n"+$line+"`n"}}
        }else{
            $h=Hash-Bytes ($utf8.GetBytes($current))
            if($h -eq $entry.after_sha256){continue}
            if($h -ne $entry.before_sha256){throw ('Edited target retained; zero source writes: '+$entry.path)}
            $payload=Join-Path $package $entry.payload;Plain-Path $payload;$after=Read-Canonical $payload
            if((Hash-Bytes ($utf8.GetBytes($after))) -ne $entry.after_sha256){throw 'Payload hash mismatch'}
        }
        $bytes=Preserve-Text $after $before
        if((Hash-Bytes $bytes) -ne (Hash-Bytes $before)){$plan.Add(@{path=$entry.path;Target=$target;Before=$before;Bytes=$bytes;Remove=$false})}
    }
    foreach($entry in $manifest.removals){
        $target=Target $entry.path;if(-not(Test-Path -LiteralPath $target -PathType Leaf)){continue}
        $before=[IO.File]::ReadAllBytes($target)
        if((Hash-Bytes $before) -ne $entry.sha256){throw ('Edited removal candidate retained; zero source writes: '+$entry.path)}
        $plan.Add(@{path=$entry.path;Target=$target;Before=$before;Bytes=$null;Remove=$true})
    }
    foreach($row in $plan){
        $backup=Join-Path $reportDir ('original/'+$row.path);[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backup))|Out-Null
        [IO.File]::WriteAllBytes($backup,$row.Before)
        if((Hash-Bytes ([IO.File]::ReadAllBytes($backup))) -ne (Hash-Bytes $row.Before)){throw 'Backup verification failed'}
    }
    foreach($row in $plan){
        if((Hash-Bytes ([IO.File]::ReadAllBytes($row.Target))) -ne (Hash-Bytes $row.Before)){throw ('Concurrent edit retained: '+$row.path)}
        if($row.Remove){[IO.File]::Delete($row.Target)}else{Write-Atomic $row.Target $row.Bytes}
        $written.Add($row)
    }
    $receipt=@{batch=$manifest.batch;project=$project;source_commit=$manifest.source_commit;files=@($plan|ForEach-Object{@{path=$_.path;before_sha256=(Hash-Bytes $_.Before);after_sha256=$(if($_.Remove){''}else{Hash-Bytes $_.Bytes})}});saves_cache_native='UNCHANGED';aab='NOT_RUN';deploy='NOT_RUN'}
    [IO.File]::WriteAllText((Join-Path $reportDir 'APPLY_RECEIPT.json'),($receipt|ConvertTo-Json -Depth 8),$utf8)
    $success=$true
    Write-Host ('REPOSITORY_CLEANUP_APPLY=PASS; SOURCE_WRITES='+$written.Count+'; RESTORE_RECEIPT='+(Join-Path $reportDir 'APPLY_RECEIPT.json'))
    exit 0
}catch{
    if(-not $success -and $written.Count -gt 0){
        foreach($row in @($written.ToArray())[-1..-($written.Count)]){
            try{
                if(Test-Path -LiteralPath $row.Target){
                    $expected=if($row.Remove){''}else{Hash-Bytes $row.Bytes}
                    if((Hash-Bytes ([IO.File]::ReadAllBytes($row.Target))) -ne $expected){throw 'Concurrent edit'}
                }
                Write-Atomic $row.Target $row.Before
            }catch{Write-Host ('ROLLBACK_REQUIRES_REVIEW='+$row.path)}
        }
    }
    Write-Error $_ -ErrorAction Continue;Write-Host 'REPOSITORY_CLEANUP=STOPPED; NO_EXPORT_OR_DEPLOY';exit 1
}
