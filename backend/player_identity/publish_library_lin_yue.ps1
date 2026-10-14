$ErrorActionPreference = 'Stop'
$paths = @(
    '.github/workflows/library-lin-yue-qa.yml',
    '.github/workflows/player-identity-qa.yml',
    'assets/character/player/player_lin_yue_idle_walk_spriteframes.tres',
    'assets/character/player/polish_20261014/death.png',
    'assets/character/player/polish_20261014/death.png.import',
    'assets/character/player/polish_20261014/idle_hurt.png',
    'assets/character/player/polish_20261014/idle_hurt.png.import',
    'assets/character/player/polish_20261014/packing.json',
    'assets/character/player/polish_20261014/sources/.gdignore',
    'assets/character/player/polish_20261014/sources/idle_hurt_death.png',
    'assets/character/player/polish_20261014/sources/walk_all.png',
    'assets/character/player/polish_20261014/sources/walk_side.png',
    'assets/character/player/polish_20261014/walk.png',
    'assets/character/player/polish_20261014/walk.png.import',
    'assets/ui/library/fonts/LICENSE.txt',
    'assets/ui/library/fonts/archive_serif.ttf',
    'assets/ui/library/fonts/archive_serif.ttf.import',
    'assets/ui/library/jade_archive_bg.png',
    'assets/ui/library/jade_archive_bg.png.import',
    'backend/player_identity/apply_library_lin_yue.cmd',
    'backend/player_identity/apply_library_lin_yue.ps1',
    'backend/player_identity/deploy_library_lin_yue.cmd',
    'backend/player_identity/deploy_library_lin_yue.ps1',
    'backend/player_identity/mail.mjs',
    'backend/player_identity/mail.test.mjs',
    'backend/player_identity/mail_reward_catalog.json',
    'backend/player_identity/mail_rewards.mjs',
    'backend/player_identity/pavilion.mjs',
    'backend/player_identity/pavilion.test.mjs',
    'backend/player_identity/publish_library_lin_yue.cmd',
    'backend/player_identity/publish_library_lin_yue.ps1',
    'docs/checkpoints/LESSONS.md',
    'docs/checkpoints/LIBRARY_LIN_YUE_2026-10-14.md',
    'scripts/data/equipment_catalog.gd',
    'scripts/managers/inventory_manager.gd',
    'scripts/managers/pavilion_banner_client.gd',
    'scripts/managers/pavilion_manager.gd',
    'scripts/player/lin_yue_frame_driver.gd',
    'scripts/player/lin_yue_frame_driver.gd.uid',
    'scripts/player/lin_yue_premium_presentation.gd',
    'scripts/player/player_1.gd',
    'scripts/ui/equipment_manager.gd',
    'scripts/ui/home_production_presenter.gd',
    'scripts/ui/library_skill_reader.gd',
    'scripts/ui/library_skill_reader.gd.uid',
    'scripts/ui/skill_book_screen.gd',
    'tests/arsenal_acquisition_probe.gd',
    'tests/arsenal_asset_audit.py',
    'tests/arsenal_integration_smoke.gd',
    'tests/arsenal_presentation_smoke.gd',
    'tests/arsenal_restart_smoke.gd',
    'tests/library_render_fixture.gd',
    'tests/lin_yue_library_smoke.gd',
    'tests/lin_yue_library_smoke.gd.uid',
    'tests/mailbox_skill_book_smoke.gd',
    'tools/art/pack_lin_yue.py'
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
        & git commit -m 'feat(game): add Library, retire Bell and polish Lin Yue locomotion'
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
