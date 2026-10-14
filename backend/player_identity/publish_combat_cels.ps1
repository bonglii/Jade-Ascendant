$ErrorActionPreference = 'Stop'
$paths = @(
    '.github/workflows/combat-cel-qa.yml',
    'assets/effects/combat_cels/art_direction.json',
    'assets/effects/combat_cels/blades.png',
    'assets/effects/combat_cels/blades.png.import',
    'assets/effects/combat_cels/hostile.png',
    'assets/effects/combat_cels/hostile.png.import',
    'assets/effects/combat_cels/impacts.png',
    'assets/effects/combat_cels/impacts.png.import',
    'assets/effects/combat_cels/packing.json',
    'assets/effects/combat_cels/sources/.gdignore',
    'assets/effects/combat_cels/sources/blades.png',
    'assets/effects/combat_cels/sources/hostile.png',
    'assets/effects/combat_cels/sources/impacts.png',
    'assets/shaders/hostile_cel_palette.gdshader',
    'assets/shaders/hostile_cel_palette.gdshader.uid',
    'assets/weapons/sword/yin_yang_blades_spriteframes.tres',
    'backend/player_identity/apply_combat_cels.cmd',
    'backend/player_identity/apply_combat_cels.ps1',
    'backend/player_identity/publish_combat_cels.cmd',
    'backend/player_identity/publish_combat_cels.ps1',
    'docs/checkpoints/COMBAT_CEL_POLISH_2026-10-14.md',
    'scripts/data/skill_catalog.gd',
    'scripts/effects/combat_cel_art.gd',
    'scripts/effects/combat_cel_art.gd.uid',
    'scripts/effects/combat_feedback.gd',
    'scripts/effects/skill_instance_polish.gd',
    'scripts/enemy/enemy_2.gd',
    'scripts/enemy/enemy_5.gd',
    'scripts/enemy/enemy_6.gd',
    'scripts/enemy/enemy_projectile.gd',
    'scripts/enemy/hostile_attack_polish.gd',
    'scripts/enemy/lightning_strike.gd',
    'scripts/enemy/qi_explosion.gd',
    'scripts/enemy/realm_lightning_strike.gd',
    'scripts/enemy/realm_qi_explosion.gd',
    'scripts/enemy/regular_attack_presence.gd',
    'scripts/enemy/regular_attack_presence.gd.uid',
    'scripts/ui/level_up.gd',
    'scripts/weapon/fire_orb.gd',
    'scripts/weapon/fire_orb_impact.gd',
    'scripts/weapon/heavenly_sword_rain.gd',
    'scripts/weapon/run_combat_ledger.gd',
    'scripts/weapon/spirit_sword.gd',
    'scripts/weapon/spirit_sword_impact.gd',
    'scripts/weapon/yin_yang_blade.gd',
    'scripts/weapon/yin_yang_blades_weapon.gd',
    'tests/combat_cel_asset_audit.py',
    'tests/combat_cel_render_fixture.gd',
    'tests/combat_cel_smoke.gd',
    'tests/run_report_smoke.gd',
    'tests/yin_yang_coverage_probe.gd'
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
        & git commit -m 'feat(combat): polish attack cels and expand level7 Yin Yang orbit'
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
