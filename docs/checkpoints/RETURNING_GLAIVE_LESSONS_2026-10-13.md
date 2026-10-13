# Returning Glaive — implementation lessons (2026-10-13)

- Validate nested GDScript phase handlers before runtime fixtures. An initially misindented closure-damage block failed script loading; the runtime parse gate caught it before delivery.
- Typed Godot arrays carry their element type. An untyped fixture literal cannot be passed to an Array[Node] parameter even when it contains Nodes. Focused fixtures explicitly construct the typed array before testing collision phases.
- Assert that crescent paths mirror around the aim line rather than assuming a positive-Y convention for Vector2.orthogonal. Godot's handedness made the original directional fixture assertion incorrect; the geometric mirror check is now explicit.
- High-resolution engraved weapons need mipmaps and linear filtering at combat sprite size. Native review caught sparkling aliasing; the final512px import uses mipmaps and the flight/preview opt into linear mip filtering.
- Keep new lessons in a uniquely named file in incremental patches. Shared LESSONS.md and old publisher/configuration files are not patch preconditions; divergent fixtures must still apply successfully.
- New catalog capability is separate from jade-chain-v1. Existing chain APKs must keep their own gifts while unknown glaive gifts stay hidden and unreserved until the APK update.
