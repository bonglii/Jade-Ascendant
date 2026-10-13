param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $RepositoryRoot
try {
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch. Main/production are protected.' }
    $origin = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch '^https://github\.com/bonglii/Jade-Ascendant(?:\.git)?$|^git@github\.com:bonglii/Jade-Ascendant(?:\.git)?$') { throw 'Unexpected repository remote.' }
    $paths = @(
        'scripts/ui/hero_unified_screen.gd',
        'scripts/ui/home_production_presenter.gd',
        'tests/hero_loadout_profile_smoke.gd',
        'docs/checkpoints/HERO_LOADOUT_PROFILE_2026-10-13.md',
        'docs/checkpoints/HERO_LOADOUT_PROFILE_LESSONS_2026-10-13.md',
        'backend/player_identity/publish_hero_stability.ps1',
        'backend/player_identity/publish_hero_stability.cmd'
    )
    foreach ($path in $paths) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Required patch file missing: ' + $path) } }
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect staging.' }
    foreach ($path in $staged) { if ($path -and $path -notin $paths) { throw ('Other staged changes exist; publish those separately first: ' + $path) } }
    & git fetch --no-tags origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect remote checkpoint. Nothing committed.' }
    $remoteSha = (& git rev-parse FETCH_HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve remote checkpoint.' }
    & git merge-base --is-ancestor $remoteSha HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Remote checkpoint is ahead/diverged. Do not force-push.' }
    $outbound = @(& git diff --name-only ($remoteSha + '..HEAD'))
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect outbound changes.' }
    foreach ($path in $outbound) { if ($path -and $path -notin $paths) { throw ('Outbound commits contain unrelated changes: ' + $path) } }
    & git add -- $paths
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage HERO stability/profile files.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged whitespace check failed.' }
    & git diff --cached --quiet
    $diffCode = $LASTEXITCODE
    if ($diffCode -gt 1) { throw 'Could not inspect staged diff.' }
    if ($diffCode -eq 1) {
        & git commit -m 'fix(hero): stabilize equipment toggles and enrich profile shortcut'
        if ($LASTEXITCODE -ne 0) { throw 'Checkpoint commit failed.' }
    }
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'GitHub push failed; local commit is retained. Retry this launcher; do not force-push.' }
    $sha = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect local checkpoint after push.' }
    $remote = @(& git ls-remote origin ('refs/heads/' + $branch))
    if ($LASTEXITCODE -ne 0 -or $remote.Count -ne 1 -or ($remote[0] -split '\s+')[0] -ne $sha) { throw 'Push verification failed; no completion claimed.' }
    Write-Host 'HERO_STABILITY_PROFILE_PUSH=PASS'
    Write-Host ('GITHUB_COMMIT_URL=https://github.com/bonglii/Jade-Ascendant/commit/' + $sha)
    Write-Host 'MAIN=UNCHANGED; IAP=UNCHANGED; SERVER_DEPLOY=NOT_REQUIRED'
} finally { Pop-Location }
