# Jade seal branding refresh — 2026-10-18

Jade jian, emerald dragon and restrained engraved gold replace the geometric seal. The same generated original artwork supplies the launcher, adaptive icon, boot seal, title lockup and Play artwork. No external trademark/reference artwork was used.

Changed: Android launcher/adaptive/monochrome icons, native splash icon/background, Godot fallback splash, initial branded loading scene, account-entry title logo and outdated cloud-backup tooltip. Opening overlaps local scene loading instead of stacking another transition screen. Reduced effects uses a static presentation with a shorter minimum.

Unchanged: Lin Yue moving main-menu background/layout, combat, equipment, economy, IAP verification/delivery, servers, purchases, Google/Guest authentication implementation, version code and signing credentials. Installer merges only branding configuration keys and preserves local export settings. It does not build or upload an AAB or deploy Workers.

QA: isolated Godot 4.7.2 fixture checks Google versus Guest routing, one identity refresh, reduced effects, five portrait/landscape sizes, retry presentation and real imported title texture. Account destination is stubbed: this does not prove Android native splash timing or a live Google login. Final Android mask/splash appearance needs observation in the next exported build.

Play files: release/store/play_icon_512.png (512 square, opaque); feature_graphic_1024x500.png (opaque, no unsupported claim text). Source masters are retained. Reproduce exports with Python tools/generate_branding.py and Inkscape. PNGs are runtime sources; SVG wrappers are authoring sources.
