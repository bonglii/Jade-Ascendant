$ErrorActionPreference = 'Stop'
$paths = (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'iap_client_v2_paths.json')) | ConvertFrom-Json
function Stage-JadePackage([string[]]$AllowedPaths) {
    # Literal per-file pathspecs avoid wildcard expansion and identify the failing file.
    # Force-add is restricted to approved binary/import resources, never source/secrets.
    foreach ($path in $AllowedPaths) {
        if ($path -notmatch '^[A-Za-z0-9_.\-/]+$' -or $path -match '(^|/)\.\.(/|$)' -or [IO.Path]::IsPathRooted($path)) { throw ('Unsafe package path: ' + $path) }
        $literal = ':(literal)' + $path
        $tracked = @(& git ls-files -- $literal)
        if ($LASTEXITCODE -ne 0) { throw ('Cannot inspect tracked package path: ' + $path) }
        $force = $false
        if ($tracked.Count -eq 0) {
            & git check-ignore -q -- $path
            $ignoredResult = $LASTEXITCODE
            if ($ignoredResult -ne 0 -and $ignoredResult -ne 1) { throw ('Cannot inspect ignore rules: ' + $path) }
            if ($ignoredResult -eq 0) {
                $approvedAsset = $path -match '^assets/[A-Za-z0-9_./-]+\.(?:webp|ogv|svg|import|uid)$' -or $path -match '^scripts/[A-Za-z0-9_./-]+\.gd\.uid$' -or $path -match '^addons/JadeMonetizationNativeBridge/bin/(?:debug|release)/JadeMonetizationNativeBridge-(?:debug|release)\.aar$'
                if (-not $approvedAsset) { throw ('Package source is ignored by Git; no forced staging: ' + $path) }
                $force = $true
            }
        }
        # Windows PowerShell treats native stderr differently from PowerShell 7.
        # Collect it without losing Git's exit code or stopping on harmless warnings.
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            if ($force) { $output = @(& git add -f -- $literal 2>&1) }
            else { $output = @(& git add -- $literal 2>&1) }
            $result = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        if ($result -ne 0) { throw ('Cannot stage package file: ' + $path + [Environment]::NewLine + ($output -join [Environment]::NewLine)) }
        if ($force) { Write-Host ('APPROVED_IGNORED_ASSET_STAGED=' + $path) }
    }
}

function Repair-JadeStagedWhitespace([string[]]$AllowedPaths) {
    $report = @(& git -c core.quotePath=false diff --cached --check -- $AllowedPaths)
    $checkResult = $LASTEXITCODE
    if ($checkResult -eq 0) { return }
    if ($checkResult -ne 2 -and $checkResult -ne 1) { throw 'Cannot inspect staged whitespace.' }
    $linesByPath = @{}
    foreach ($entry in $report) {
        if ($entry -match '^(.+):([0-9]+): trailing whitespace\.$') {
            $path = $Matches[1]
            if ($AllowedPaths -notcontains $path) { throw ('Whitespace outside the package: ' + $path) }
            if (-not $linesByPath.ContainsKey($path)) { $linesByPath[$path] = @() }
            $linesByPath[$path] += [int]$Matches[2]
        }
    }
    if ($linesByPath.Count -eq 0) { throw 'Git reported a different whitespace error. No automatic repair was made.' }
    foreach ($path in $linesByPath.Keys) {
        $stagedHash = (& git rev-parse (':' + $path)).Trim()
        if ($LASTEXITCODE -ne 0) { throw ('Cannot inspect staged file: ' + $path) }
        $workingHash = (& git hash-object --path=$path -- $path).Trim()
        if ($LASTEXITCODE -ne 0 -or $workingHash -ne $stagedHash) { throw ('File changed after staging; retry without overwriting edits: ' + $path) }
        $absolute = Join-Path (Get-Location).Path $path
        $bytes = [IO.File]::ReadAllBytes($absolute)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
        $offset = 0
        if ($hasBom) { $offset = 3 }
        $strictUtf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false, $true
        $text = $strictUtf8.GetString($bytes, $offset, $bytes.Length - $offset)
        $lines = [regex]::Split($text, '(?<=\n)')
        foreach ($line in $linesByPath[$path]) {
            $index = $line - 1
            if ($index -lt 0 -or $index -ge $lines.Length) { throw ('Staged line is outside the file: ' + $path) }
            $lines[$index] = [regex]::Replace($lines[$index], '[ \t]+(?=\r?\n?\z)', '')
        }
        $normalized = [string]::Join('', $lines)
        if ($normalized -eq $text) { throw ('The reported line could not be repaired safely: ' + $path) }
        $token = [Guid]::NewGuid().ToString('N')
        $temporary = $absolute + '.jade-whitespace-' + $token + '.tmp'
        $backup = $absolute + '.jade-whitespace-' + $token + '.bak'
        if (-not [IO.Path]::IsPathRooted($absolute) -or -not [IO.Path]::IsPathRooted($temporary) -or -not [IO.Path]::IsPathRooted($backup)) { throw 'Repair paths must be absolute.' }
        try {
            $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $hasBom
            [IO.File]::WriteAllText($temporary, $normalized, $encoding)
            [IO.File]::Replace($temporary, $absolute, $backup)
        } finally {
            if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        }
        & git add -- $path
        if ($LASTEXITCODE -ne 0) { throw ('Cannot restage repaired file; original retained at: ' + $backup) }
        if ([IO.File]::Exists($backup)) { [IO.File]::Delete($backup) }
        Write-Host ('WHITESPACE_REPAIRED=' + $path + '; LINES=' + $linesByPath[$path].Count)
    }
}

Push-Location (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
try {
    $lock = (& git rev-parse --git-path index.lock).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve Git index lock path.' }
    if (Test-Path -LiteralPath $lock) { throw 'Git index.lock exists. Stop the other Git process before retrying. This publisher never removes locks.' }
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch. Main is protected.' }
    $origin = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch '^https://github\.com/bonglii/Jade-Ascendant(?:\.git)?$|^git@github\.com:bonglii/Jade-Ascendant(?:\.git)?$') { throw 'Unexpected GitHub repository.' }
    foreach ($path in $paths) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Missing package file: ' + $path) } }
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect staged changes.' }
    foreach ($path in $staged) { if ($paths -notcontains $path) { throw ('Unrelated staged file; preserve it before publishing: ' + $path) } }
    $remoteRef = 'FETCH_HEAD'
    & git fetch --no-tags origin ('refs/heads/' + $branch)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch checkpoint. Nothing committed.' }
    & git rev-parse --verify ($remoteRef + '^{commit}')
    if ($LASTEXITCODE -ne 0) { throw 'Fetched checkpoint reference is missing or invalid. Nothing committed.' }
    & git merge-base --is-ancestor $remoteRef HEAD
    $ancestryResult = $LASTEXITCODE
    if ($ancestryResult -eq 1) { throw 'Remote checkpoint is not an ancestor of HEAD. It may be behind/diverged or local history may be shallow. Nothing committed; no force push.' }
    if ($ancestryResult -ne 0) { throw 'Cannot inspect checkpoint ancestry. Nothing committed.' }
    $outbound = @(& git diff --name-only $remoteRef HEAD)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect pending commits.' }
    foreach ($path in $outbound) { if ($paths -notcontains $path) { throw ('Unrelated outgoing change: ' + $path) } }
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect staged changes.' }
    foreach ($path in $staged) { if ($paths -notcontains $path) { throw ('Unrelated staged change: ' + $path) } }
    Stage-JadePackage -AllowedPaths $paths
    Repair-JadeStagedWhitespace -AllowedPaths $paths
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace check failed. No commit was made.' }
    & git diff --cached --quiet
    $difference = $LASTEXITCODE
    if ($difference -eq 1) {
        & git commit -m 'fix(iap): normalize Windows staging SQL arguments'
        if ($LASTEXITCODE -ne 0) { throw 'Commit failed.' }
    } elseif ($difference -ne 0) { throw 'Cannot inspect package changes.' }
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'Push failed. The local commit has not been published.' }
    $sha = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect local commit.' }
    $remote = @(& git ls-remote origin ('refs/heads/' + $branch))
    if ($LASTEXITCODE -ne 0 -or $remote.Count -ne 1 -or ($remote[0] -split '\s+')[0] -ne $sha) { throw 'Remote commit verification failed.' }
    Write-Host 'SOURCE_CHECKPOINT_ONLY=1; REEXPORT=WAIT_FOR_NATIVE_AND_GODOT_CI'
    Write-Host 'GITHUB_QA_URL=https://github.com/bonglii/Jade-Ascendant/actions/workflows/iap-delivery-qa.yml'
    Write-Host ('GITHUB_COMMIT_URL=https://github.com/bonglii/Jade-Ascendant/commit/' + $sha)
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { Pop-Location }
