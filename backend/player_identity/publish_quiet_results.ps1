$ErrorActionPreference = 'Stop'
$paths = @(
    'AGENTS.md',
    'backend/player_identity/publish_combat_fairness.cmd',
    'backend/player_identity/publish_combat_fairness.ps1',
    'docs/checkpoints/COMBAT_FAIRNESS_2026-10-14.md',
    'scripts/data/equipment_catalog.gd',
    'scripts/data/equipment_set_catalog.gd',
    'scripts/data/skill_catalog.gd',
    'scripts/effects/actor_presentation.gd',
    'scripts/effects/equipment_set_status.gd',
    'scripts/player/PlayerHealth.gd',
    'scripts/ui/level_up.gd',
    'scripts/ui/skill_book_screen.gd',
    'scripts/weapon/celestial_returning_glaive_weapon.gd',
    'scripts/weapon/jade_binding_chain_weapon.gd',
    'scripts/weapon/returning_glaive_flight.gd',
    'scripts/weapon/weapon_manager.gd',
    'tests/balance_audit_export.gd',
    'tests/combat_fairness_smoke.gd',
    'tests/cultivation_mastery_smoke.gd',
    'tests/hero_equipment_progression_smoke.gd',
    'tests/returning_glaive_smoke.gd',
    'scripts/ui/equipment_manager.gd',
    'scripts/managers/idle_cultivation_manager.gd',
    'tests/economy_progression_smoke.gd',
    'docs/checkpoints/ECONOMY_PROGRESSION_2026-10-14.md',
    'backend/player_identity/publish_economy_progression.cmd',
    'backend/player_identity/publish_economy_progression.ps1',
    'scripts/data/chapter_one_catalog.gd',
    'scripts/data/chapter_two_catalog.gd',
    'scripts/data/chapter_three_catalog.gd',
    'scripts/data/chapter_four_catalog.gd',
    'scripts/data/chapter_five_catalog.gd',
    'scripts/enemy/enemy_spawner.gd',
    'tests/elite_pacing_smoke.gd',
    'tests/boss_duration_probe.gd',
    'docs/checkpoints/ELITE_PACING_DURATION_2026-10-14.md',
    'docs/checkpoints/BOSS_DURATION_DATA_2026-10-14.json',
    'backend/player_identity/publish_elite_pacing.cmd',
    'backend/player_identity/publish_elite_pacing.ps1',
    'scripts/managers/announcement_center.gd',
    'scripts/managers/checkpoint_manager.gd',
    'scripts/ui/VictoryUI.gd',
    'scripts/ui/liveops/mailbox_screen.gd',
    'scripts/ui/result_ceremony.gd',
    'scripts/weapon/run_combat_ledger.gd',
    'scripts/weapon/run_combat_ledger.gd.uid',
    'tests/run_report_smoke.gd',
    'tests/run_report_smoke.gd.uid',
    'tests/mailbox_paper_region_smoke.gd',
    'docs/checkpoints/QUIET_RESULTS_REPORT_2026-10-14.md',
    'backend/player_identity/publish_quiet_results.cmd',
    'backend/player_identity/publish_quiet_results.ps1',
    'scripts/weapon/eight_trigrams_formation.gd',
    'scripts/weapon/fire_orb.gd',
    'scripts/weapon/heavenly_lightning.gd',
    'scripts/weapon/heavenly_sword_rain.gd',
    'scripts/weapon/jade_binding_cast.gd',
    'scripts/weapon/spirit_sword.gd',
    'scripts/weapon/thunder_talisman_weapon.gd',
    'scripts/weapon/yin_yang_blades_weapon.gd',
    'assets/ui/results/quiet/button_jade_hover.svg',
    'assets/ui/results/quiet/button_jade_normal.svg',
    'assets/ui/results/quiet/button_jade_pressed.svg',
    'assets/ui/results/quiet/button_navy_hover.svg',
    'assets/ui/results/quiet/button_navy_normal.svg',
    'assets/ui/results/quiet/button_navy_pressed.svg',
    'assets/ui/results/quiet/button_red_hover.svg',
    'assets/ui/results/quiet/button_red_normal.svg',
    'assets/ui/results/quiet/button_red_pressed.svg',
    'assets/ui/results/quiet/crimson.svg',
    'assets/ui/results/quiet/jade.svg',
    'assets/ui/results/quiet/paper.svg',
    'assets/ui/results/quiet/button_jade_hover.svg.import',
    'assets/ui/results/quiet/button_jade_normal.svg.import',
    'assets/ui/results/quiet/button_jade_pressed.svg.import',
    'assets/ui/results/quiet/button_navy_hover.svg.import',
    'assets/ui/results/quiet/button_navy_normal.svg.import',
    'assets/ui/results/quiet/button_navy_pressed.svg.import',
    'assets/ui/results/quiet/button_red_hover.svg.import',
    'assets/ui/results/quiet/button_red_normal.svg.import',
    'assets/ui/results/quiet/button_red_pressed.svg.import',
    'assets/ui/results/quiet/crimson.svg.import',
    'assets/ui/results/quiet/jade.svg.import',
    'assets/ui/results/quiet/paper.svg.import'
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
        & git commit -m 'feat(results): simplify sheets and show saved weapon damage and run skills'
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
