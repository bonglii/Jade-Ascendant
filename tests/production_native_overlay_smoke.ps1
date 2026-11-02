param([string]$PriorCandidate='')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $repo 'backend/player_identity/production_native_overlay.ps1')
$checks=0
$cases=0
function Check([bool]$Ok,[string]$Caption) {
    $script:checks++
    if(-not $Ok){throw ('NATIVE_OVERLAY_FAIL: '+$Caption)}
}
function Reject([scriptblock]$Work,[string]$Pattern,[string]$Caption) {
    $caught=''
    try { & $Work } catch { $caught=$_.Exception.Message }
    Check ($caught -match $Pattern) $Caption
}
function Put([string]$Path,[byte[]]$Bytes) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Path)) -Force | Out-Null
    [IO.File]::WriteAllBytes($Path,$Bytes)
}
function Fixture([byte[]]$Original) {
    $script:cases++
    $project=Join-Path $temporary ('project with spaces '+$script:cases)
    $release=Join-Path $project 'addons/bridge-release.aar'
    $candidate=Join-Path $project 'release/candidate.aar'
    $sessions=Join-Path $project '.local/production_native_export'
    $marker=Join-Path $sessions 'active.json'
    Put $release $Original;Put $candidate $candidateBytes
    New-Item -ItemType Directory -Path $sessions -Force | Out-Null
    return @{Project=$project;Release=$release;Candidate=$candidate;SessionRoot=$sessions;Marker=$marker;OriginalHash=(Get-JadeNativeHash $release);CandidateHash=$candidateHash}
}
function Invoke-OverlayStart($f) { return Start-JadeNativeOverlay @f }
function Restore($f,[string[]]$Hashes=@($candidateHash)) {
    Restore-JadeNativeOverlay -Project $f.Project -Release $f.Release -SessionRoot $f.SessionRoot -Marker $f.Marker -CandidateHashes $Hashes
}
function Rewrite($f,$state) {[IO.File]::WriteAllText($f.Marker,($state|ConvertTo-Json))}
$candidateBytes=[IO.File]::ReadAllBytes((Join-Path $repo 'release/native/JadeMonetizationNativeBridge-production-candidate.aar'))
$candidateHash=(Get-FileHash -LiteralPath (Join-Path $repo 'release/native/JadeMonetizationNativeBridge-production-candidate.aar') -Algorithm SHA256).Hash.ToLowerInvariant()
$locked=[IO.File]::ReadAllBytes((Join-Path $repo 'addons/JadeMonetizationNativeBridge/bin/release/JadeMonetizationNativeBridge-release.aar'))
$opaque=[Text.Encoding]::UTF8.GetBytes('owner-provided build; not approved as candidate')
$originals=@($locked,$candidateBytes,$opaque)
if($PriorCandidate){$originals+=,[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $PriorCandidate).Path)}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('jade-native-overlay-'+[Guid]::NewGuid().ToString('N'))
try {
    foreach($original in $originals){
        $f=Fixture $original;$state=Invoke-OverlayStart $f
        Check ((Get-JadeNativeHash $f.Release)-eq$candidateHash) 'only the verified candidate is placed into export slot'
        Check ($state.original_hash-eq$f.OriginalHash) 'receipt records actual owner hash instead of a fixed locked build'
        Check ((Get-JadeNativeHash $state.backup_path)-eq$f.OriginalHash) 'exact original backup is verified'
        Restore $f
        Check ((Get-JadeNativeHash $f.Release)-eq$f.OriginalHash) 'successful export cleanup restores exact original bytes'
        Check (-not(Test-Path -LiteralPath $f.Marker)) 'successful restoration clears only its receipt'
        Check (Test-Path -LiteralPath $state.backup_path) 'backup remains available'
    }
    $f=Fixture $opaque;$state=Invoke-OverlayStart $f
    Put $f.Release ([Text.Encoding]::UTF8.GetBytes('another process changed the owner file'))
    $changed=Get-JadeNativeHash $f.Release
    Reject {Restore $f} 'changed outside' 'external changes are held, never overwritten during recovery'
    Check ((Get-JadeNativeHash $f.Release)-eq$changed -and (Test-Path -LiteralPath $f.Marker)) 'external file and recovery receipt survive rejection'

    $f=Fixture $opaque;$state=Invoke-OverlayStart $f
    Put $state.backup_path ([Text.Encoding]::UTF8.GetBytes('corrupt backup'))
    Reject {Restore $f} 'backup hash mismatch' 'corrupt original backup is rejected'
    Check ((Get-JadeNativeHash $f.Release)-eq$candidateHash -and (Test-Path -LiteralPath $f.Marker)) 'candidate and receipt held when backup is corrupt'

    $f=Fixture $opaque;$state=Invoke-OverlayStart $f
    $outside=Join-Path $temporary 'outside-original-release.aar';Put $outside $opaque
    $state.backup_path=$outside;Rewrite $f $state
    Reject {Restore $f} 'outside owned' 'backup path cannot escape its project session directory'
    Check ((Get-JadeNativeHash $f.Release)-eq$candidateHash) 'path rejection performs no native overwrite'

    $f=Fixture $opaque;$state=Invoke-OverlayStart $f
    $state.project=Join-Path $temporary 'wrong-project';Rewrite $f $state
    Reject {Restore $f} 'project mismatch' 'receipt cannot restore into another project'

    $f=Fixture $opaque;$state=Invoke-OverlayStart $f
    $state.candidate_hash='b'*64;Rewrite $f $state
    Reject {Restore $f} 'Unrecognized' 'an unrecognized export candidate cannot authorize recovery'

    $f=Fixture $opaque
    Put $f.Release ([Text.Encoding]::UTF8.GetBytes('owner changed it before export'))
    $changed=Get-JadeNativeHash $f.Release
    Reject {Invoke-OverlayStart $f} 'changed before export' 'original file is rechecked before starting an overlay'
    Check ((Get-JadeNativeHash $f.Release)-eq$changed -and -not(Test-Path -LiteralPath $f.Marker)) 'preflight rejection leaves original and no marker'

    $f=Fixture $opaque
    Put $f.Candidate ([Text.Encoding]::UTF8.GetBytes('wrong candidate'))
    Reject {Invoke-OverlayStart $f} 'changed before export' 'candidate hash is checked before changing original'
    Check ((Get-JadeNativeHash $f.Release)-eq$f.OriginalHash) 'wrong candidate cannot overwrite original'

    $f=Fixture $opaque;$state=Invoke-OverlayStart $f;$markerBytes=[IO.File]::ReadAllText($f.Marker)
    Reject {Invoke-OverlayStart $f} 'receipt already exists' 'second exporter cannot replace an owned recovery receipt'
    Check ([IO.File]::ReadAllText($f.Marker)-eq$markerBytes) 'owned receipt is unchanged after duplicate attempt'
    Restore $f

    # A pre-R2 receipt has no version. Recover the exact old session candidate.
    $f=Fixture $locked;$state=Invoke-OverlayStart $f;$state.Remove('version');Rewrite $f $state
    Restore $f
    Check ((Get-JadeNativeHash $f.Release)-eq$f.OriginalHash) 'legacy R1 receipt remains recoverable'
    if($PriorCandidate){
        $f=Fixture $locked
        $priorBytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $PriorCandidate).Path)
        Put $f.Candidate $priorBytes;$f.CandidateHash=Get-JadeNativeHash $f.Candidate
        $state=Invoke-OverlayStart $f;$state.Remove('version');Rewrite $f $state
        Restore $f @($candidateHash,$f.CandidateHash)
        Check ((Get-JadeNativeHash $f.Release)-eq$f.OriginalHash) 'historical production candidate receipt restores correctly after R2'
    }
    Write-Output ('NATIVE_OVERLAY checks='+$checks+' cases='+$cases+' failures=0; HOST=PowerShell '+$PSVersionTable.PSVersion+'; WINDOWS=NOT_TESTED; AAB_EXPORT=NOT_TESTED')
} finally {
    if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}
}
