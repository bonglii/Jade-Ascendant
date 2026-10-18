# Odyssey imperial presentation and economy v2

This batch includes the previously delivered recovered-command integer correction. All 15 command variants are canonicalized, including recovered journals, with original request identity preserved.

## Presentation
- Generated ivory/jade dice and matching sculpted gold/jade UI atlas are integrated as real assets. Exact pips remain code-drawn to match the server die, with no generated numeral ambiguity.
- Board geometry fills the available width, temple scale increases, and Lin Yue's sprite frame display grows from 40px to 70–106px with directional walk animation and per-step lift.
- A large die reveal precedes token travel. Pending network results do not invent an authoritative face or move the token. Input stays locked throughout reveal/travel; reduced effects preserve timing/meaning with less motion.
- Larger tactile buttons, carved back/info/close medallions, readable milestone cards/progress, mission cards, optional Jade packs and a separate cost confirmation.
- Popups own a higher layer; the board token cannot pierce them. Decorative corners are sliced within verified gutters; tall panels do not stretch the entire marble center. No visible scrollbars.
- Closing a pending path/challenge leaves a main-action button to resume it. Account/season changes cancel stale presentations before they can move the new account's token.
- Milestone ceremony uses the actual Compass/dragon art, folding tiles and bounded texture sparks rather than placeholder polygon/ring effects.

## Economy and compatibility
- New native requests use /v2/odyssey: 10 Purchased Jade for one die, 40 for five (20% bundle saving). Existing /v1/odyssey retains 25/100 for old clients. An old server does not recognize v2 and therefore cannot silently charge a legacy price for a new-client request.
- Six free dice/day remain unchanged: three login plus three mission dice. 72 rolls require 12 fully active days under this cadence, within the 14-day event; this is not a guarantee for missed mission claims. Two verified ad dice/day remain optional.
- Purchase caps remain 10/day and 40/season. Four five-packs per 20 dice cost 160 Jade; 40 bought dice cost 320 Jade. Extra purchases do not alter die odds or award extra Compass copies.
- Retry receipts are stable across versions: a previously committed command returns its original response/cost without another debit. Wallet guards, refund holds, SSV verification, gacha/IAP prices, event schedules, rewards and schemas remain unchanged.

## Export and delivery
- Release metadata reads the verified native proof hash instead of a stale hardcoded candidate digest.
- Android release export records the actual output path locally. The post-export AAB check validates metadata, native candidate hash, UI contract and v2 native DEX markers before printing the exact AAB path/hash to upload.
- PC workflow: install/isolated Godot checks, recover any owned completed export session, rebuild/verify native candidate, scoped Git publish, deploy code-only Workers update, open production export launcher, verify final AAB. No secret rotation or schema migration; existing event stays as configured.
- Local pure-JVM/Node/Godot/render evidence is separate from the full Android build, deployment and Play-installed device check, which run on the owner's PC/device.
