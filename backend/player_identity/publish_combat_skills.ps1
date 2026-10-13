$ErrorActionPreference = 'Stop'
$paths = @(
    'assets/shaders/premium_actor.gdshader',
    'scripts/data/boss_premium_catalog.gd',
    'scripts/effects/actor_presentation.gd',
    'scripts/effects/skill_signature_art.gd',
    'scripts/effects/skill_instance_polish.gd',
    'scripts/enemy/boss_1.gd',
    'scripts/enemy/boss_premium_presentation.gd',
    'scripts/enemy/hostile_attack_polish.gd',
    'scripts/enemy/enemy_projectile.gd',
    'scripts/enemy/lightning_strike.gd',
    'scripts/enemy/qi_explosion.gd',
    'scripts/player/lin_yue_premium_presentation.gd',
    'scripts/player/PlayerHealth.gd',
    'scripts/player/skill_ascension_feedback.gd',
    'scripts/ui/level_up.gd',
    'scripts/ui/skill_choice_engraving.gd',
    'scripts/weapon/spirit_sword.gd',
    'scripts/weapon/fire_orb.gd',
    'scripts/weapon/yin_yang_blade.gd',
    'scripts/weapon/heavenly_sword_rain.gd',
    'scripts/weapon/eight_trigrams_formation.gd',
    'scripts/weapon/thunder_talisman_strike.gd',
    'scripts/weapon/heavenly_lightning.gd',
    'tests/combat_skill_polish_smoke.gd',
    'docs/checkpoints/COMBAT_SKILLS_POLISH_2026-10-14.md',
    'backend/player_identity/publish_combat_skills.ps1',
    'backend/player_identity/publish_combat_skills.cmd'
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
        & git commit -m 'feat(combat): refine locomotion, boss windups and all 18 run-skill presentations'
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
