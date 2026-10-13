param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $RepositoryRoot
try {
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch. Main/production are protected.' }
    $origin = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch '^https://github\.com/bonglii/Jade-Ascendant(?:\.git)?$|^git@github\.com:bonglii/Jade-Ascendant(?:\.git)?$') { throw 'Unexpected repository remote.' }
    $paths = @(
        'scripts/ui/CultivationMenu.gd',
        'scripts/ui/hud.gd',
        'scripts/ui/hud_combat_polish.gd',
        'scripts/ui/achievement_unlock_presenter.gd',
        'scripts/ui/encounter_notice_layout.gd',
        'scripts/ui/encounter_notice_layout.gd.uid',
        'tests/combat_notice_layout_smoke.gd',
        'docs/checkpoints/COMBAT_NOTICES_FIX_2026-10-13.md',
        'docs/checkpoints/COMBAT_NOTICES_LESSONS_2026-10-13.md',
        'backend/player_identity/publish_combat_notices.cmd',
        'backend/player_identity/publish_combat_notices.ps1',
        'scripts/managers/save_manager.gd',
        'scripts/managers/GameSession.gd',
        'scripts/stats/player_stats.gd',
        'scripts/player/player_1.gd',
        'scripts/player/PlayerHealth.gd',
        'scripts/effects/combat_feedback.gd',
        'scripts/data/cultivation_mastery_catalog.gd',
        'scripts/data/cultivation_mastery_runtime.gd',
        'scripts/managers/cultivation_mastery_manager.gd',
        'scripts/effects/cultivation_mastery_pulse.gd',
        'scripts/ui/cultivation_mastery_panel.gd',
        'tests/cultivation_mastery_smoke.gd',
        'tests/mastery_stats_fixture.gd',
        'scripts/data/cultivation_mastery_catalog.gd.uid',
        'scripts/data/cultivation_mastery_runtime.gd.uid',
        'scripts/managers/cultivation_mastery_manager.gd.uid',
        'scripts/effects/cultivation_mastery_pulse.gd.uid',
        'scripts/ui/cultivation_mastery_panel.gd.uid',
        'docs/checkpoints/CULTIVATION_MASTERY_2026-10-13.md',
        'docs/checkpoints/CULTIVATION_MASTERY_LESSONS_2026-10-13.md',
        'backend/player_identity/publish_cultivation.cmd',
        'backend/player_identity/publish_cultivation.ps1',
        'scripts/managers/pavilion_manager.gd',
        'scripts/ui/pavilion_sanctum_screen.gd',
        'backend/player_identity/pavilion_dashboard.mjs',
        'tests/pavilion_weapon_picker_smoke.gd',
        'backend/player_identity/pavilion_weapon_picker.test.mjs',
        'docs/checkpoints/PAVILION_WEAPON_PICKER_2026-10-13.md',
        'docs/checkpoints/PAVILION_WEAPON_PICKER_LESSONS_2026-10-13.md',
        'backend/player_identity/publish_weapon_picker.cmd',
        'backend/player_identity/publish_weapon_picker.ps1',
        'backend/player_identity/deploy_weapon_picker.cmd',
        'backend/player_identity/deploy_weapon_picker.ps1',
        'scripts/ui/hero_unified_screen.gd',
        'tests/hero_upgrade_burst_smoke.gd',
        'assets/ui/hero/equipped/equipped_frame.svg',
        'assets/ui/hero/equipped/equipped_frame.svg.import',
        'docs/checkpoints/HERO_UPGRADE_BURST_2026-10-13.md',
        'docs/checkpoints/HERO_UPGRADE_BURST_LESSONS_2026-10-13.md',
        'backend/player_identity/publish_hero_upgrade.cmd',
        'backend/player_identity/publish_hero_upgrade.ps1',
        'scripts/ui/home_production_presenter.gd',
        'tests/hero_loadout_profile_smoke.gd',
        'docs/checkpoints/HERO_LOADOUT_PROFILE_2026-10-13.md',
        'docs/checkpoints/HERO_LOADOUT_PROFILE_LESSONS_2026-10-13.md',
        'backend/player_identity/publish_hero_stability.cmd',
        'backend/player_identity/publish_hero_stability.ps1'
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
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage combat notice files.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged whitespace check failed.' }
    & git diff --cached --quiet
    $diffCode = $LASTEXITCODE
    if ($diffCode -gt 1) { throw 'Could not inspect staged diff.' }
    if ($diffCode -eq 1) {
        & git commit -m 'fix(ui): center boss notices and preserve readable achievement duration'
        if ($LASTEXITCODE -ne 0) { throw 'Checkpoint commit failed.' }
    }
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'GitHub push failed; local commit is retained. Retry this launcher; do not force-push.' }
    $sha = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect local checkpoint after push.' }
    $remote = @(& git ls-remote origin ('refs/heads/' + $branch))
    if ($LASTEXITCODE -ne 0 -or $remote.Count -ne 1 -or ($remote[0] -split '\s+')[0] -ne $sha) { throw 'Push verification failed; no completion claimed.' }
    Write-Host 'COMBAT_NOTICES_PUSH=PASS'
    Write-Host ('GITHUB_COMMIT_URL=https://github.com/bonglii/Jade-Ascendant/commit/' + $sha)
    Write-Host 'MAIN=UNCHANGED; IAP=UNCHANGED; BACKEND_DEPLOY=NOT_REQUIRED'
} finally { Pop-Location }
