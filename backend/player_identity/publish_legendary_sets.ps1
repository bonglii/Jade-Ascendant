$ErrorActionPreference = 'Stop'
$paths = @(
    '.github/workflows/legendary-set-vfx-qa.yml',
    'assets/effects/legendary_sets/art_direction.json',
    'assets/effects/legendary_sets/celestial_aegis.png',
    'assets/effects/legendary_sets/celestial_aegis.png.import',
    'assets/effects/legendary_sets/nine_heavens.png',
    'assets/effects/legendary_sets/nine_heavens.png.import',
    'assets/effects/legendary_sets/packing.json',
    'assets/effects/legendary_sets/solar_meridian.png',
    'assets/effects/legendary_sets/solar_meridian.png.import',
    'assets/effects/legendary_sets/sources/.gdignore',
    'assets/effects/legendary_sets/sources/celestial_aegis.png',
    'assets/effects/legendary_sets/sources/nine_heavens.png',
    'assets/effects/legendary_sets/sources/solar_meridian.png',
    'assets/effects/legendary_sets/sources/vermilion_verdict.png',
    'assets/effects/legendary_sets/vermilion_verdict.png',
    'assets/effects/legendary_sets/vermilion_verdict.png.import',
    'backend/player_identity/apply_legendary_sets.cmd',
    'backend/player_identity/apply_legendary_sets.ps1',
    'backend/player_identity/publish_legendary_sets.cmd',
    'backend/player_identity/publish_legendary_sets.ps1',
    'docs/checkpoints/LEGENDARY_SET_VFX_2026-10-14.md',
    'scripts/effects/equipment_set_combat.gd',
    'scripts/player/legendary_set_art.gd',
    'scripts/player/legendary_set_art.gd.uid',
    'scripts/player/legendary_set_vfx.gd',
    'scripts/player/legendary_set_vfx.gd.uid',
    'scripts/player/lin_yue_equipment_set_presentation.gd',
    'scripts/weapon/run_combat_ledger.gd',
    'tests/legendary_set_asset_audit.py',
    'tests/legendary_set_render_fixture.gd',
    'tests/legendary_set_render_fixture.gd.uid',
    'tests/legendary_set_vfx_smoke.gd',
    'tests/legendary_set_vfx_smoke.gd.uid',
    'tools/art/pack_legendary_sets.py'
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
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect staged changes.' }
    foreach ($path in $staged) { if ($paths -notcontains $path) { throw ('Unrelated staged change: ' + $path) } }
    & git add -- $paths
    if ($LASTEXITCODE -ne 0) { throw 'Cannot stage package.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace check failed.' }
    & git diff --cached --quiet
    $difference = $LASTEXITCODE
    if ($difference -eq 1) {
        & git commit -m 'feat(vfx): add premium four-piece Legendary set resonance'
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
