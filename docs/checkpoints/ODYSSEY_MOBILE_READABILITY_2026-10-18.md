# Odyssey phone readability R2

Evidence: user screenshot showed an oversized travel-dice badge, a tiny/flattened diamond board and four integer-division editor warnings.

Changes: header die fixed at 52px instead of a 96px minimum that could stretch; 20 server positions retain their order in an upright rectangular loop, with a minimum 480px board region, 38–54px resource icons and 118–148px Lin Yue presentation. A generated emerald/gold square tile replaces the distorted wide panel. A clear central tile label explains the occupied tile. Countdown truncation now uses explicit floating division.

Validation: isolated Godot layout at 648×1152, 648×1296 and 720×1600; all 20 unique positions stay in bounds, token art stays vertically inside at corners, footer actions remain visible, badge stays 52×52. Existing reveal/travel, account switch, pending-choice and grace flow tests retained. Integer-division warnings are errors in the isolated fixture. Rendered UI inspected separately from any phone/device test.

Only presentation/source changed. Server positions, die odds, rewards, prices, transactions, native API and event state are unchanged. Reuse the existing verified native proof; no server deployment. Release metadata/AAB verification require presentation revision 3 to prevent uploading the previous export.
