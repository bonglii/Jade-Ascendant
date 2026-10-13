# Distinct Event identities — 2026-10-13

## Outcome

The native baseline showed seven activity cards; five unrelated events used the same red gateway icon. The approved Seven Days illustration and Treasury popup frame are retained. Five new original ImageGen landscape illustrations now identify Pilgrimage (jade valley), Boss Hunt (crimson arena), Heavenly Ladder (azure ascent), Treasure Hunt (jade cache), and Five Elements (five pictorial elemental medallions). Daily Trials and Pavilion use their own existing artwork. Provenance, prompts and SHA-256 hashes are in `assets/ui/liveops/event_identity/asset_sources.json`.

Cards display readable wide artwork, distinct accent colors, full titles/descriptions and the existing authoritative progress/status/CTA. Buttons reuse the installed imperial jade material. Matching illustrations and distinct thumbnails appear on the five detail screens; their existing realm backgrounds stay progression-aware. Long detail labels/buttons wrap rather than expanding the portrait width, with a readable minimum line height for status pills. The original event IDs, navigation destinations, touch scroll guard, reward routes and managers are preserved.

Ambient artwork uses one native Control with a bounded eight-particle overlay, at most 20 redraws/second. Offscreen scroll cards stop redraws. Reduced effects suppresses animation and repaints once when toggled; claim-ready decoration follows LiveOpsManager's actual readiness. The artwork import caps the runtime long edge to 1024px without editing original PNGs (five RGBA surfaces approximately 10 MiB instead of ~30 MiB). Source images remain full quality and are never replaced in place.

A responsive defect was found in the old Event Center: setting popup width before its rows changed columns could clamp it against the previous wide minimum. Width is now reapplied after the responsive containers settle, keeping frame/content aligned at 320px, 390px, standard portrait and landscape sizes. Deferred layout validates the current generation and attached controls after each await, including immediate close/reopen.

## Validation and scope

- Native QA: 566 checks, zero failures; covers EN/ID, five consecutive resize shapes, seven distinct card identities, artwork memory cap, material CTAs, correct signal-bound navigation IDs, progress/readiness updates, touch drag guards, offscreen/reduced-effects behavior, five matching detail screens, Home popup mode, and twelve rapid-close cases.
- Economy, claimed markers, inventory and Pavilion state are compared before/after presentation, resize, readiness previews and opening detail screens. Presentation does not grant or claim rewards.
- Existing repeating-login tests: 364 checks; restart: eight checks; zero failures. Managers/save schema are unchanged. All 48 identity/mail/banner backend tests also pass for publisher preflight.
- Actual Godot 4.7.2 OpenGL screenshots and a native video are reviewed. Two resource-exit warnings also occur in the unchanged baseline fixture; no claim is made that this patch resolves whole-engine shutdown warnings.
- Main, parked IAP, backend deployment/configuration and weapon gameplay are outside this patch. Unrelated workspace equipment bitmap changes are preserved and excluded.

## Install

Requires the preceding Pavilion Imperial/Banners patch. Incremental patch base tree: `67e5ec262b8a8c8539acab012d901d7ebc1b7a35`.

From Windows CMD in `D:\Godot\project\jade-ascendant`:

```bat
git apply --check "D:\Godot\tools\Jade-Ascendant-Event-Identities.patch" && git apply "D:\Godot\tools\Jade-Ascendant-Event-Identities.patch"
```

Open Godot to import the new images, then re-export Android once. No Worker deployment is required. Existing mutable `publish_paths.json` and existing publishers are not patched. The new `backend\player_identity\publish_events.cmd` uses the explicit System32 PowerShell executable, unions an explicit allowlist with existing published paths, protects the authorized checkpoint branch, runs backend checks, pushes normally and prints a verified GitHub commit URL. GitHub integration write was rejected with 403 in the preceding task; no new remote publication is claimed here. Windows execution occurs on the user's deployment laptop.

## Next weapon proposal — Jade Binding Chain

This is a design proposal, not an implemented or balanced weapon in this patch. Existing Spirit Sword, Fire Orb, Thunder Talisman, Yin-Yang Blades, Heavenly Sword Rain and Eight Trigrams Formation were inspected. Thunder Talisman already supplies lightning-chain hits; the distinct missing role is brief group movement control followed by delayed burst.

Proposed loop: acquire a nearby cluster through the existing attack-range rules; bind a limited number of real targets with jade qi chains; apply a short slow; telegraph one delayed qi detonation; deal damage once through player stats and the existing enemy damage authority. Upgrades increase linked targets and detonation radius. Bosses receive a lighter movement effect, without repeatable immobilization or interruption of existing telegraphs. Normal enemies should not be pulled through obstacles; no offscreen target chaining or unlimited extra targets. VFX should show casting seal → emerald links → tension glow → pale-gold break/qi shockwave, with a quieter reduced-effects variant. Numeric damage, slow duration and cooldown remain tentative until the scheduled HP/damage/economy audit.

The intended synergy is keeping packs in Fire Orb / Sword Rain / Eight Trigrams damage zones while giving the player room to reposition, rather than adding another unconditional damage source.
