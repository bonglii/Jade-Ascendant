# Complete default warning pass — 2026-10-18

Base: 5a997ce1438b45f8c2fe3dbd8ebf2f07e47c89cb on checkpoint/iap-fasttrack-20261010.

Five incompatible numeric ternary expressions are corrected in skill_signature_art, lin_yue_equipment_set_presentation, and home_sanctuary_presenter. Float constants keep exactly the same numeric values, layout coordinates and effect timing.

The expanded pass also finds a local hash name shadowing the built-in function, two unused locals, and one intentionally unused attack-helper argument. Rename the digest, remove the unused pure cost lookup/Node lookup, and name the unused argument _player without changing positional calls. Integrity comparisons, checksum keys, attack math and paid authority remain unchanged.

QA: all 301 production scripts load with every default enabled warning category promoted to error in an isolated project. Production project settings, native plugins, servers, saves, IAP configuration and Android export settings are untouched. No live purchase/deployment is performed. setup_warning_cleanup_qa.py now discovers the engine's complete enabled category list instead of hardcoding three categories.

Installer/publisher uses exact payload/source hashes and backups, preserves unrelated edits, commits to the checkpoint branch only and prints the real GitHub commit link. Append-note staging is generalized and hash checked. No force push or automatic Git lock removal.
