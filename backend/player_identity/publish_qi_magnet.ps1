$ErrorActionPreference = 'Stop'
$paths = @(
    'assets/pickups/jade_qi_magnet.svg',
    'assets/pickups/jade_qi_magnet.svg.import',
    'scripts/pickups/qi_magnet.gd',
    'scripts/pickups/qi_magnet.gd.uid',
    'scripts/pickups/xp_gem.gd',
    'scripts/enemy/enemy_spawner.gd',
    'scripts/enemy/realm_enemy_spawner.gd',
    'scripts/managers/checkpoint_manager.gd',
    'tests/qi_magnet_smoke.gd',
    'docs/checkpoints/QI_MAGNET_2026-10-13.md',
    'backend/player_identity/publish_qi_magnet.ps1',
    'backend/player_identity/publish_qi_magnet.cmd'
)
Push-Location (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
try {
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch. Main is protected.' }
    $origin = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch '^https://github\.com/bonglii/Jade-Ascendant(?:\.git)?$|^git@github\.com:bonglii/Jade-Ascendant(?:\.git)?$') { throw 'Unexpected GitHub repository.' }
    foreach ($path in $paths) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Missing package file: ' + $path) } }
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect staged changes.' }
    foreach ($path in $staged) { if ($paths -notcontains $path) { throw ('Unrelated staged file; preserve it before publishing: ' + $path) } }
    $remoteRef = 'refs/remotes/origin/' + $branch
    $fetchSpec = 'refs/heads/' + $branch + ':' + $remoteRef
    & git fetch --no-tags origin $fetchSpec
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
    & git add -- $paths
    if ($LASTEXITCODE -ne 0) { throw 'Cannot stage package.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace check failed.' }
    & git diff --cached --quiet
    $difference = $LASTEXITCODE
    if ($difference -eq 1) {
        & git commit -m 'feat(combat): add milestone jade magnets that gather earned map XP'
        if ($LASTEXITCODE -ne 0) { throw 'Commit failed.' }
    } elseif ($difference -ne 0) { throw 'Cannot inspect package changes.' }
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'Push failed. The local commit has not been published.' }
    $sha = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect local commit.' }
    $remote = @(& git ls-remote origin ('refs/heads/' + $branch))
    if ($LASTEXITCODE -ne 0 -or $remote.Count -ne 1 -or ($remote[0] -split '\s+')[0] -ne $sha) { throw 'Remote commit verification failed.' }
    Write-Host ('GITHUB_COMMIT_URL=https://github.com/bonglii/Jade-Ascendant/commit/' + $sha)
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally { Pop-Location }
