# Combat and run-skill presentation pass

Base checkpoint: aea263d plus the delivered warning cleanup.
User clarification: Skill Book is the authoritative roster reference; its page
is unchanged. Polish the actual 18 run skills, their level-up choices and real
gameplay feedback. Main, parked IAP, Google login and all mail/admin routes stay
outside this package. No server deployment is required.

## Asset audit and resulting behavior
Inspected Lin Yue's 4-direction atlas, disciple walk frames, boss action atlases,
existing skill artwork and real native Godot captures. Existing art already has
frames; weak stride and stiff transforms are the issue. Reuse the approved art
and engraved card skins, with no asset replacement or bitmap generation needed.

Lin Yue's gait follows actual distance, settles when blocked, and articulates
the cloth hem within the active atlas frame. Shadow/footsteps/trails retain
fixed storage. Common/elite actors and all 26 boss encounters get travel-driven
body motion. Common caster animations also trigger a brief hand crest. Only
the presentation owner writes sprite transforms; gameplay colliders are stable.

Boss single projectile winds up for 0.24 seconds and aims at the captured player
position. Radial volley winds up for 0.312 seconds; alternating volleys rotate
existing gaps by half a projectile spacing. Counts, HP, damage, range and
cooldowns remain as configured. Pending casts respect pause, cannot duplicate,
and cancel on death or a phase change. This intentional attack behavior change
gives players a readable opportunity to sidestep. Realm IV/V authored signature
patterns retain their original owner and rules.

## All 18 run skills
Choices use textured engraved frames and individual emblems while retaining
real effects, state labels and progression. After a real selected upgrade, one
brief player-side acknowledgement identifies the art and its applied benefit.
The benefit is captured before upgrading so it never advertises the next level.

Six active arts gain bounded flight/impact details: Spirit Sword, Fire Orb,
Thunder Talisman, Yin-Yang Blades, Heavenly Sword Rain and Eight Trigrams.
Resonance swords, empowered reversal orbits and Heavenly Tribulation receive
additional signature accents only when the actual state is active. The two new
Legendary armaments retain their own rendering authority.

Nine passive arts have distinct choice/upgrade signatures: Power, Attack Speed,
Swift Qi, Body Refinement, Qi Shield, Spiritual Insight, Iron Body, Blood Qi and
Sword Intent. Actual shield consumption and actual Blood Qi healing receive
their own brief proc glyph. No recovery glyph is emitted at full HP. Passive
stat bonuses are not represented as permanent AoE attacks.

Extra friendly spell ornaments are capped globally at 40 and release their
budget with their parent. Hostile accents share the existing cap of 64. Idle
body ticks remain budgeted; extra spell drawing is suppressed by Reduced
Effects. Attack radii and actual impact timing stay with the original skills.

## Validation
261 focused Godot checks: all 18 choices at 320x568/390x844/648x1152, actual
upgrade/proc hooks, 8 common/elite bodies, 26 boss colliders, pause/aim/windup/
death/phase cancellation, shifted volley gaps and FX budget lifecycle.
Also ran 472 existing combat checks and 268 existing skill/level-up checks.
Native Compatibility rendering and a staged 5-second video were inspected.
Small-window QA preserves the production 648x1152 canvas_items/expand scaling;
disabling stretch in a fixture is not a valid phone-layout comparison.
Fixtures use isolated saves and the Chapter I arena to inspect presentation;
they are not a map redesign or a production run/progression example.
Desktop QA does not establish Android GPU FPS; phone review follows re-export.
Baseline teardown ObjectDB/resource warnings remain documented; no script or
shader failure is accepted during runtime. Windows PowerShell is unavailable
here; its launcher is reviewed, not claimed as executed on Windows.

## Apply / publish
Apply Jade-Ascendant-Combat-Skills-Polish.patch after the warning fixes, reopen
Godot and re-export Android. Run backend\player_identity\publish_combat_skills.cmd
to publish the explicit package on checkpoint/iap-fasttrack-20261010. It checks
origin, checkpoint ancestry and unrelated staged/outgoing paths, creates the
remote-tracking ref explicitly and never force-pushes. It prints a commit URL
only after verifying the remote SHA. No GitHub push occurred in this session.

## Lessons
Record the user's Skill Book clarification before changing the page. Avoid
compiling autoload-dependent QA scripts before autoload initialization; load
them inside the running test. Keep atlas alpha sampling bounded and avoid
custom sampler helper calls that caused a Godot shader diagnostic. Snapshot
an applied upgrade benefit before mutation, not after. Preserve one transform
owner and tie decorative proc feedback to a real gameplay event.
