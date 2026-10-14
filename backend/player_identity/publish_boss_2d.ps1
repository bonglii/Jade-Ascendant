$ErrorActionPreference = 'Stop'
$paths = @(
    'assets/enemy/boss_2d/asset_sources.json',
    'assets/enemy/boss_2d/atlas_1_1.png',
    'assets/enemy/boss_2d/atlas_1_1.png.import',
    'assets/enemy/boss_2d/atlas_1_2.png',
    'assets/enemy/boss_2d/atlas_1_2.png.import',
    'assets/enemy/boss_2d/atlas_1_3.png',
    'assets/enemy/boss_2d/atlas_1_3.png.import',
    'assets/enemy/boss_2d/atlas_1_4.png',
    'assets/enemy/boss_2d/atlas_1_4.png.import',
    'assets/enemy/boss_2d/atlas_1_5.png',
    'assets/enemy/boss_2d/atlas_1_5.png.import',
    'assets/enemy/boss_2d/atlas_2_1.png',
    'assets/enemy/boss_2d/atlas_2_1.png.import',
    'assets/enemy/boss_2d/atlas_2_2.png',
    'assets/enemy/boss_2d/atlas_2_2.png.import',
    'assets/enemy/boss_2d/atlas_2_3.png',
    'assets/enemy/boss_2d/atlas_2_3.png.import',
    'assets/enemy/boss_2d/atlas_2_4.png',
    'assets/enemy/boss_2d/atlas_2_4.png.import',
    'assets/enemy/boss_2d/atlas_2_5.png',
    'assets/enemy/boss_2d/atlas_2_5.png.import',
    'assets/enemy/boss_2d/atlas_3_1.png',
    'assets/enemy/boss_2d/atlas_3_1.png.import',
    'assets/enemy/boss_2d/atlas_3_2.png',
    'assets/enemy/boss_2d/atlas_3_2.png.import',
    'assets/enemy/boss_2d/atlas_3_3.png',
    'assets/enemy/boss_2d/atlas_3_3.png.import',
    'assets/enemy/boss_2d/atlas_3_4.png',
    'assets/enemy/boss_2d/atlas_3_4.png.import',
    'assets/enemy/boss_2d/atlas_3_5.png',
    'assets/enemy/boss_2d/atlas_3_5.png.import',
    'assets/enemy/boss_2d/atlas_4_1.png',
    'assets/enemy/boss_2d/atlas_4_1.png.import',
    'assets/enemy/boss_2d/atlas_4_2.png',
    'assets/enemy/boss_2d/atlas_4_2.png.import',
    'assets/enemy/boss_2d/atlas_4_3.png',
    'assets/enemy/boss_2d/atlas_4_3.png.import',
    'assets/enemy/boss_2d/atlas_4_4.png',
    'assets/enemy/boss_2d/atlas_4_4.png.import',
    'assets/enemy/boss_2d/atlas_4_5.png',
    'assets/enemy/boss_2d/atlas_4_5.png.import',
    'assets/enemy/boss_2d/atlas_5_1.png',
    'assets/enemy/boss_2d/atlas_5_1.png.import',
    'assets/enemy/boss_2d/atlas_5_2.png',
    'assets/enemy/boss_2d/atlas_5_2.png.import',
    'assets/enemy/boss_2d/atlas_5_3.png',
    'assets/enemy/boss_2d/atlas_5_3.png.import',
    'assets/enemy/boss_2d/atlas_5_4.png',
    'assets/enemy/boss_2d/atlas_5_4.png.import',
    'assets/enemy/boss_2d/atlas_5_5.png',
    'assets/enemy/boss_2d/atlas_5_5.png.import',
    'scripts/enemy/boss_frame_driver.gd',
    'scripts/effects/actor_presentation.gd',
    'tests/boss_frame_driver_smoke.gd',
    'tests/boss_atlas_gutters.gd',
    'tests/combat_skill_polish_smoke.gd',
    'docs/checkpoints/BOSS_2D_CELS_2026-10-14.md',
    'backend/player_identity/publish_boss_2d.ps1',
    'backend/player_identity/publish_boss_2d.cmd',
    'scripts/data/boss_premium_catalog.gd',
    'scripts/data/boss_refinement_art.gd',
    'scripts/enemy/boss_1.gd',
    'scripts/enemy/boss_pressure_motion.gd',
    'scripts/enemy/realm_boss.gd',
    'scripts/enemy/boss_premium_presentation.gd',
    'scripts/enemy/hostile_attack_polish.gd',
    'tests/boss_refinement_smoke.gd',
    'tests/boss_autofire_gap_smoke.gd',
    'tests/premium_batch2_smoke.gd',
    'docs/checkpoints/BOSS_REFINEMENT_2026-10-14.md',
    'docs/checkpoints/BOSS_REFINEMENT_LESSONS_2026-10-14.md',
    'assets/enemy/refined/asset_sources.json',
    'assets/enemy/refined/realm_1_atlas.png',
    'assets/enemy/refined/realm_1_atlas.png.import',
    'assets/enemy/refined/realm_2_atlas.png',
    'assets/enemy/refined/realm_2_atlas.png.import',
    'assets/enemy/refined/realm_3_atlas.png',
    'assets/enemy/refined/realm_3_atlas.png.import',
    'assets/enemy/refined/realm_4_atlas.png',
    'assets/enemy/refined/realm_4_atlas.png.import',
    'assets/enemy/refined/realm_5_atlas.png',
    'assets/enemy/refined/realm_5_atlas.png.import',
    'backend/player_identity/publish_boss_refinement.ps1',
    'backend/player_identity/publish_boss_refinement.cmd',
    'scripts/player/PlayerHealth.gd',
    'scripts/ui/level_up.gd',
    'scripts/data/economy_catalog.gd',
    'scripts/monetization/admob_provider.gd',
    'scripts/ui/pavilion_runtime_screen.gd',
    'tests/balance_audit_export.gd',
    'tests/admob_reward_fence_fixture.gd',
    'tests/balance_ads_smoke.gd',
    'tools/check_rewarded_ads.ps1',
    'tools/check_rewarded_ads.cmd',
    'docs/checkpoints/BALANCE_AUDIT_2026-10-13.md',
    'docs/checkpoints/BALANCE_ADS_2026-10-14.md',
    'backend/player_identity/publish_balance_ads.ps1',
    'backend/player_identity/publish_balance_ads.cmd'
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
        & git commit -m 'feat(boss): ship padded 2D cels with distance-driven steps and cast timing'
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
