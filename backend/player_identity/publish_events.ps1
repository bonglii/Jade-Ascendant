param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $RepositoryRoot
try {
    $branch = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -ne 'checkpoint/iap-fasttrack-20261010') { throw 'Use the authorized checkpoint branch; main/production are protected.' }
    $origin = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'github\.com[:/]bonglii/Jade-Ascendant(?:\.git)?$') { throw 'Unexpected repository remote.' }
    $paths = @(Get-Content -Raw -LiteralPath 'backend/player_identity/publish_paths.json' | ConvertFrom-Json)
    $gachaPaths = @(
        'scripts/ui/liveops/event_center_screen.gd',
        'scripts/ui/liveops/event_identity_banner.gd',
        'scripts/ui/liveops/event_identity_banner.gd.uid',
        'scripts/ui/liveops/event_identity_catalog.gd',
        'scripts/ui/liveops/event_identity_catalog.gd.uid',
        'tests/event_identity_smoke.gd',
        'backend/player_identity/publish_events.cmd',
        'backend/player_identity/publish_events.ps1',
        'docs/checkpoints/EVENT_IDENTITIES_2026-10-13.md',
        'assets/ui/liveops/event_identity/asset_sources.json',
        'assets/ui/liveops/event_identity/pilgrimage.png',
        'assets/ui/liveops/event_identity/pilgrimage.png.import',
        'assets/ui/liveops/event_identity/boss_hunt.png',
        'assets/ui/liveops/event_identity/boss_hunt.png.import',
        'assets/ui/liveops/event_identity/heavenly_ladder.png',
        'assets/ui/liveops/event_identity/heavenly_ladder.png.import',
        'assets/ui/liveops/event_identity/treasure_hunt.png',
        'assets/ui/liveops/event_identity/treasure_hunt.png.import',
        'assets/ui/liveops/event_identity/five_elements.png',
        'assets/ui/liveops/event_identity/five_elements.png.import',
        'scripts/ui/liveops/jade_valley_pilgrimage_screen.gd',
        'scripts/ui/liveops/celestial_boss_hunt_screen.gd',
        'scripts/ui/liveops/heavenly_ladder_screen.gd',
        'scripts/ui/liveops/celestial_treasure_hunt_screen.gd',
        'scripts/ui/liveops/path_of_five_elements_screen.gd',

        'backend/player_identity/mail_reward_catalog.json',
        'backend/player_identity/mail_rewards.mjs',
        'backend/player_identity/build_mail_assets.mjs',
        'scripts/managers/reward_manager.gd',
        'scripts/ui/reward_claim_result_presenter.gd',
        'tests/server_mail_gifts_smoke.gd',
        'tests/server_mail_gifts_smoke.gd.uid',
        'docs/checkpoints/MAIL_REWARDS_STUDIO_2026-10-12.md',
        'backend/player_identity/pavilion.mjs',
        'backend/player_identity/pavilion_dashboard.mjs',
        'backend/player_identity/pavilion_schema.sql',
        'backend/player_identity/pavilion.test.mjs',
        'backend/player_identity/deploy_pavilion.cmd',
        'backend/player_identity/deploy_pavilion.ps1',
        'backend/player_identity/publish_pavilion.cmd',
        'backend/player_identity/publish_pavilion.ps1',
        'scripts/managers/pavilion_banner_client.gd',
        'scripts/managers/pavilion_banner_client.gd.uid',
        'scripts/ui/pavilion_imperial_style.gd',
        'scripts/ui/pavilion_imperial_style.gd.uid',
        'tests/pavilion_banner_smoke.gd',
        'assets/ui/pavilion/sanctum_premium/imperial_jade_frame.png',
        'assets/ui/pavilion/sanctum_premium/imperial_jade_frame.png.import',
        'docs/checkpoints/PAVILION_BANNERS_AND_IMPERIAL_UI_2026-10-13.md',

        'assets/ui/pavilion/sanctum_premium/pavilion_unified.png',
        'assets/ui/pavilion/sanctum_premium/pavilion_unified.png.import',
        'tests/pavilion_secrecy_render_smoke.gd',
        'docs/checkpoints/PAVILION_UNIFIED_REVEAL_2026-10-13.md',
        'assets/ui/pavilion/sanctum_premium/celestial_dragon.png',
        'assets/ui/pavilion/sanctum_premium/celestial_seal.png',
        'assets/ui/pavilion/sanctum_premium/celestial_seal.png.import',
        'assets/ui/pavilion/sanctum_premium/asset_sources.json',
        'assets/ui/pavilion/sanctum_premium/celestial_dragon.png.import',
        'assets/ui/pavilion/sanctum_premium/celestial_gate.png.import',
        'assets/ui/pavilion/sanctum_premium/celestial_gate.png',
        'scripts/ui/idle_cultivation_presenter_premium.gd',
        'scripts/managers/daily_quest_manager.gd',
        'scripts/managers/live_ops_manager.gd',
        'scripts/managers/pavilion_manager.gd',
        'scripts/managers/save_manager.gd',
        'scripts/managers/server_mail_manager.gd',
        'scripts/monetization/google_play_billing_provider.gd',
        'tests/idle_modal_lifetime_smoke.gd',
        'docs/checkpoints/GACHA_PREMIUM_POLISH_2026-10-13.md',
        'scripts/ui/pavilion_sanctum_screen.gd',
        'scripts/ui/pavilion_sanctum_screen.gd.uid',
        'scripts/ui/pavilion_sanctum_stage.gd',
        'scripts/ui/pavilion_sanctum_stage.gd.uid',
        'scenes/ui/pavilion_screen.tscn',
        'scripts/managers/localization_manager.gd',
        'tests/pavilion_sanctum_smoke.gd',
        'docs/checkpoints/GACHA_SANCTUM_2026-10-13.md',
        'docs/previews/gacha-ritual-v3.html',
        'backend/player_identity/publish_gacha.ps1',
        'backend/player_identity/publish_gacha.cmd'
    )
    foreach ($path in $gachaPaths) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Required gacha patch file missing: ' + $path) } }
    $paths = @($paths + $gachaPaths | Select-Object -Unique)
    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing staging area.' }
    foreach ($path in $staged) { if ($paths -notcontains $path) { throw ('Unrelated staged file; preserve it before publishing: ' + $path) } }
    & node --test backend/player_identity/identity.test.mjs backend/player_identity/mail.test.mjs backend/player_identity/pavilion.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Identity and mail server tests failed.' }
    $availablePaths = @()
    foreach ($path in $paths) {
        if ($path -match 'node_modules|\.env|\.keystore|\.jks|firestore-debug|backend/monetization/|backend/cloud_save/') { throw ('Protected or unsafe publish path: ' + $path) }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            if ($path -like 'docs/checkpoints/*' -or $path -in @('tools/Jade-Server-Network-Diagnose.ps1','tools/Jade-Wrangler-Tail-DNS.cjs')) { continue }
            throw ('Expected patch file missing: ' + $path)
        }
        $availablePaths += $path
    }
    & git add -- $availablePaths
    if ($LASTEXITCODE -ne 0) { throw 'Unable to stage reviewed patch files.' }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged whitespace check failed.' }
    & git diff --cached --stat
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        & git commit -m 'feat(events): give each activity distinct illustrated identity'
        if ($LASTEXITCODE -ne 0) { throw 'Checkpoint commit failed.' }
    } elseif ($LASTEXITCODE -ne 0) { throw 'Unable to inspect staged changes.' }
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'GitHub push failed; local commit exists but has not been published. Do not force-push.' }
    $sha = (& git rev-parse HEAD).Trim()
    $remote = @(& git ls-remote origin ('refs/heads/' + $branch))
    if ($LASTEXITCODE -ne 0 -or $remote.Count -ne 1 -or ($remote[0] -split '\s+')[0] -ne $sha) { throw 'Remote checkpoint verification failed.' }
    Write-Host ('GITHUB_COMMIT_URL=https://github.com/bonglii/Jade-Ascendant/commit/' + $sha)
    Write-Host ('GITHUB_BRANCH_URL=https://github.com/bonglii/Jade-Ascendant/tree/' + $branch)
} finally { Pop-Location }
