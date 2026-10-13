# Skill refinement and run level congratulations

Owned weapon/passive upgrades have weight 2.5; new choices have weight 1.
Draws are without replacement after existing eligibility checks. Capped skills
and unavailable resonances remain excluded. Nothing guarantees a particular
skill: with one owned skill among 15 eligible skills and three choices, its
theoretical inclusion rate is 41.11% versus 20% for uniform sampling.

The existing run level choice panel displays congratulations and the previous
and current level, localized for English/Indonesian. It uses the approved ritual
frame and skill artwork, with no second modal, new reward, or extra pause.

Production HP remains 100. The earlier balance report used script default 10
and missed the level_1 scene override inherited by all 25 stage scenes. The
one-contact-death recommendation is withdrawn. Vitality adds up to 50 HP.

Validation after recovery used Godot 4.7.2 and the latest published checkpoint
21bf927. Patch application passed on that source while retaining Chain/Glaive
art and descriptions. The packaged suite passed 268 checks, including actual
EXP-driven level advancement and off-tree HP checks for all 25 stages. The
existing premium combat suite passed 472 checks: 740 current checks total.
20,000 draws measured 41.74% owned-skill inclusion against 20.21% uniform
inclusion in the 15-candidate/one-owned scenario. Headless tests emitted
existing shader/exit resource warnings; no script errors or failed assertions.

For an isolated local smoke run, set XDG_DATA_HOME to a directory containing
`jade_onboarding_qa`, then run Godot headless with this project and
`--script res://tests/skill_refinement_level_up_smoke.gd`. Never run this suite
against the player's normal save directory.

Apply the patch, reopen Godot to import the helper, and export Android again.
No backend deployment is required. The protected publisher only commits this
package on checkpoint/iap-fasttrack-20261010 and verifies the remote SHA before
printing a GitHub commit link.
