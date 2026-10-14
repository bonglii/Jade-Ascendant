$ErrorActionPreference = 'Stop'
$paths = @(
    'AGENTS.md',
    'assets/audio/arsenal_20261014/astral_bell.wav',
    'assets/audio/arsenal_20261014/astral_bell.wav.import',
    'assets/audio/arsenal_20261014/phoenix_fan.wav',
    'assets/audio/arsenal_20261014/phoenix_fan.wav.import',
    'assets/audio/arsenal_20261014/void_thrust.wav',
    'assets/audio/arsenal_20261014/void_thrust.wav.import',
    'assets/ui/account_gate/imperial_v1/README.md',
    'assets/ui/account_gate/imperial_v1/jade_button.png',
    'assets/ui/account_gate/imperial_v1/jade_button.png.import',
    'assets/ui/account_gate/imperial_v1/jade_wordmark.png',
    'assets/ui/account_gate/imperial_v1/jade_wordmark.png.import',
    'assets/ui/account_gate/imperial_v1/panel.svg',
    'assets/ui/account_gate/imperial_v1/panel.svg.import',
    'assets/ui/account_gate/imperial_v1/realm_background.png',
    'assets/ui/account_gate/imperial_v1/realm_background.png.import',
    'assets/ui/equipment/expansion_20261014/README.md',
    'assets/ui/equipment/expansion_20261014/astral_resonance_bell.png',
    'assets/ui/equipment/expansion_20261014/astral_resonance_bell.png.import',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_boots.png',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_boots.png.import',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_bracer.png',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_bracer.png.import',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_pendant.png',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_pendant.png.import',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_robe.png',
    'assets/ui/equipment/expansion_20261014/celestial_aegis_robe.png.import',
    'assets/ui/equipment/expansion_20261014/frost_lotus_boots.png',
    'assets/ui/equipment/expansion_20261014/frost_lotus_boots.png.import',
    'assets/ui/equipment/expansion_20261014/frost_lotus_bracer.png',
    'assets/ui/equipment/expansion_20261014/frost_lotus_bracer.png.import',
    'assets/ui/equipment/expansion_20261014/frost_lotus_pendant.png',
    'assets/ui/equipment/expansion_20261014/frost_lotus_pendant.png.import',
    'assets/ui/equipment/expansion_20261014/frost_lotus_robe.png',
    'assets/ui/equipment/expansion_20261014/frost_lotus_robe.png.import',
    'assets/ui/equipment/expansion_20261014/packing.json',
    'assets/ui/equipment/expansion_20261014/phoenix_war_fan.png',
    'assets/ui/equipment/expansion_20261014/phoenix_war_fan.png.import',
    'assets/ui/equipment/expansion_20261014/sources/.gdignore',
    'assets/ui/equipment/expansion_20261014/sources/astral_resonance_bell.png',
    'assets/ui/equipment/expansion_20261014/sources/celestial_aegis.png',
    'assets/ui/equipment/expansion_20261014/sources/frost_lotus.png',
    'assets/ui/equipment/expansion_20261014/sources/phoenix_war_fan.png',
    'assets/ui/equipment/expansion_20261014/sources/vermilion_verdict.png',
    'assets/ui/equipment/expansion_20261014/sources/void_piercer_spear.png',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_boots.png',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_boots.png.import',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_bracer.png',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_bracer.png.import',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_pendant.png',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_pendant.png.import',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_robe.png',
    'assets/ui/equipment/expansion_20261014/vermilion_verdict_robe.png.import',
    'assets/ui/equipment/expansion_20261014/void_piercer_spear.png',
    'assets/ui/equipment/expansion_20261014/void_piercer_spear.png.import',
    'assets/ui/results/quiet/button_jade_hover.svg',
    'assets/ui/results/quiet/button_jade_hover.svg.import',
    'assets/ui/results/quiet/button_jade_normal.svg',
    'assets/ui/results/quiet/button_jade_normal.svg.import',
    'assets/ui/results/quiet/button_jade_pressed.svg',
    'assets/ui/results/quiet/button_jade_pressed.svg.import',
    'assets/ui/results/quiet/button_navy_hover.svg',
    'assets/ui/results/quiet/button_navy_hover.svg.import',
    'assets/ui/results/quiet/button_navy_normal.svg',
    'assets/ui/results/quiet/button_navy_normal.svg.import',
    'assets/ui/results/quiet/button_navy_pressed.svg',
    'assets/ui/results/quiet/button_navy_pressed.svg.import',
    'assets/ui/results/quiet/button_red_hover.svg',
    'assets/ui/results/quiet/button_red_hover.svg.import',
    'assets/ui/results/quiet/button_red_normal.svg',
    'assets/ui/results/quiet/button_red_normal.svg.import',
    'assets/ui/results/quiet/button_red_pressed.svg',
    'assets/ui/results/quiet/button_red_pressed.svg.import',
    'assets/ui/results/quiet/crimson.svg',
    'assets/ui/results/quiet/crimson.svg.import',
    'assets/ui/results/quiet/jade.svg',
    'assets/ui/results/quiet/jade.svg.import',
    'assets/ui/results/quiet/paper.svg',
    'assets/ui/results/quiet/paper.svg.import',
    'backend/player_identity/apply_gate_auto_mail.cmd',
    'backend/player_identity/apply_gate_auto_mail.ps1',
    'backend/player_identity/deploy_ascendant_arsenal.cmd',
    'backend/player_identity/deploy_ascendant_arsenal.ps1',
    'backend/player_identity/mail.mjs',
    'backend/player_identity/mail.test.mjs',
    'backend/player_identity/mail_reward_catalog.json',
    'backend/player_identity/mail_rewards.mjs',
    'backend/player_identity/pavilion.mjs',
    'backend/player_identity/pavilion.test.mjs',
    'backend/player_identity/publish_ascendant_arsenal.cmd',
    'backend/player_identity/publish_ascendant_arsenal.ps1',
    'backend/player_identity/publish_combat_fairness.cmd',
    'backend/player_identity/publish_combat_fairness.ps1',
    'backend/player_identity/publish_economy_progression.cmd',
    'backend/player_identity/publish_economy_progression.ps1',
    'backend/player_identity/publish_elite_pacing.cmd',
    'backend/player_identity/publish_elite_pacing.ps1',
    'backend/player_identity/publish_gate_auto_mail.cmd',
    'backend/player_identity/publish_gate_auto_mail.ps1',
    'backend/player_identity/publish_quiet_results.cmd',
    'backend/player_identity/publish_quiet_results.ps1',
    'backend/player_identity/worker.mjs',
    'docs/checkpoints/ASCENDANT_ARSENAL_2026-10-14.md',
    'docs/checkpoints/ASCENDANT_ARSENAL_ACQUISITION_2026-10-14.json',
    'docs/checkpoints/ASCENDANT_ARSENAL_ASSETS_2026-10-14.json',
    'docs/checkpoints/BOSS_DURATION_DATA_2026-10-14.json',
    'docs/checkpoints/CELESTIAL_GATE_AUTO_MAIL_2026-10-14.md',
    'docs/checkpoints/COMBAT_FAIRNESS_2026-10-14.md',
    'docs/checkpoints/ECONOMY_PROGRESSION_2026-10-14.md',
    'docs/checkpoints/ELITE_PACING_DURATION_2026-10-14.md',
    'docs/checkpoints/QUIET_RESULTS_REPORT_2026-10-14.md',
    'scenes/ui/google_account_entry.tscn',
    'scripts/data/armament_combat_catalog.gd',
    'scripts/data/ascendant_arsenal_catalog.gd',
    'scripts/data/ascendant_arsenal_catalog.gd.uid',
    'scripts/data/chapter_five_catalog.gd',
    'scripts/data/chapter_four_catalog.gd',
    'scripts/data/chapter_one_catalog.gd',
    'scripts/data/chapter_three_catalog.gd',
    'scripts/data/chapter_two_catalog.gd',
    'scripts/data/equipment_catalog.gd',
    'scripts/data/equipment_set_catalog.gd',
    'scripts/data/skill_catalog.gd',
    'scripts/effects/actor_presentation.gd',
    'scripts/effects/celestial_aegis_guard.gd',
    'scripts/effects/celestial_aegis_guard.gd.uid',
    'scripts/effects/equipment_set_combat.gd',
    'scripts/effects/equipment_set_combat.gd.uid',
    'scripts/effects/equipment_set_status.gd',
    'scripts/enemy/enemy_spawner.gd',
    'scripts/managers/announcement_center.gd',
    'scripts/managers/audio_manager.gd',
    'scripts/managers/checkpoint_manager.gd',
    'scripts/managers/idle_cultivation_manager.gd',
    'scripts/managers/pavilion_banner_client.gd',
    'scripts/managers/server_mail_manager.gd',
    'scripts/player/PlayerHealth.gd',
    'scripts/player/lin_yue_equipment_set_presentation.gd',
    'scripts/ui/VictoryUI.gd',
    'scripts/ui/equipment_manager.gd',
    'scripts/ui/equipment_visual_catalog.gd',
    'scripts/ui/google_account_entry.gd',
    'scripts/ui/hero_unified_screen.gd',
    'scripts/ui/level_up.gd',
    'scripts/ui/liveops/mailbox_screen.gd',
    'scripts/ui/result_ceremony.gd',
    'scripts/ui/skill_book_screen.gd',
    'scripts/ui/skill_choice_engraving.gd',
    'scripts/weapon/ascendant_armament_cast.gd',
    'scripts/weapon/ascendant_armament_cast.gd.uid',
    'scripts/weapon/astral_resonance_bell_weapon.gd',
    'scripts/weapon/astral_resonance_bell_weapon.gd.uid',
    'scripts/weapon/celestial_returning_glaive_weapon.gd',
    'scripts/weapon/eight_trigrams_formation.gd',
    'scripts/weapon/equipment_weapon_art.gd',
    'scripts/weapon/fire_orb.gd',
    'scripts/weapon/heavenly_lightning.gd',
    'scripts/weapon/heavenly_sword_rain.gd',
    'scripts/weapon/jade_binding_cast.gd',
    'scripts/weapon/jade_binding_chain_weapon.gd',
    'scripts/weapon/jade_binding_slow.gd',
    'scripts/weapon/phoenix_war_fan_weapon.gd',
    'scripts/weapon/phoenix_war_fan_weapon.gd.uid',
    'scripts/weapon/returning_glaive_flight.gd',
    'scripts/weapon/run_combat_ledger.gd',
    'scripts/weapon/run_combat_ledger.gd.uid',
    'scripts/weapon/spirit_sword.gd',
    'scripts/weapon/thunder_talisman_weapon.gd',
    'scripts/weapon/void_piercer_spear_weapon.gd',
    'scripts/weapon/void_piercer_spear_weapon.gd.uid',
    'scripts/weapon/weapon_manager.gd',
    'scripts/weapon/yin_yang_blades_weapon.gd',
    'tests/arsenal_acquisition_probe.gd',
    'tests/arsenal_acquisition_probe.gd.uid',
    'tests/arsenal_asset_audit.py',
    'tests/arsenal_integration_smoke.gd',
    'tests/arsenal_integration_smoke.gd.uid',
    'tests/arsenal_presentation_smoke.gd',
    'tests/arsenal_presentation_smoke.gd.uid',
    'tests/arsenal_restart_smoke.gd',
    'tests/arsenal_restart_smoke.gd.uid',
    'tests/ascendant_arsenal_smoke.gd',
    'tests/ascendant_arsenal_smoke.gd.uid',
    'tests/balance_audit_export.gd',
    'tests/boss_duration_probe.gd',
    'tests/combat_fairness_smoke.gd',
    'tests/cultivation_mastery_smoke.gd',
    'tests/economy_progression_smoke.gd',
    'tests/elite_pacing_smoke.gd',
    'tests/gate_auto_mail_smoke.gd',
    'tests/gate_auto_mail_smoke.gd.uid',
    'tests/hero_equipment_progression_smoke.gd',
    'tests/mailbox_paper_region_smoke.gd',
    'tests/pavilion_weapon_picker_smoke.gd',
    'tests/returning_glaive_smoke.gd',
    'tests/run_report_smoke.gd',
    'tests/run_report_smoke.gd.uid'
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
        & git commit -m 'feat(ui): redesign account entrance and automate mailbox sync'
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
