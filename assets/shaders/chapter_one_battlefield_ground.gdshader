shader_type canvas_item;
render_mode unshaded;

// Chapter 1 battlefield V2: a *world-space*, repeating painted forest floor.
// Keep a combat-safe central path; nothing in this shader is a hitbox/telegraph.
// World coordinates remain stable during camera motion and checkpoints.
uniform sampler2D forest_floor : source_color, repeat_enable, filter_linear;
uniform vec4 deep_earth : source_color = vec4(0.020, 0.067, 0.061, 1.0);
uniform vec4 moss_jade : source_color = vec4(0.041, 0.145, 0.108, 1.0);
uniform vec4 wet_stone : source_color = vec4(0.028, 0.087, 0.083, 1.0);
uniform vec4 qi_jade : source_color = vec4(0.120, 0.520, 0.365, 1.0);
uniform vec4 qi_cyan : source_color = vec4(0.120, 0.430, 0.430, 1.0);

varying vec2 world_position;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float smooth_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
        mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void vertex() {
    world_position = VERTEX;
}

void fragment() {
    vec2 p = world_position;
    // 1024px texture is already made seamless, no screen-locked UV or stretching.
    vec3 base = texture(forest_floor, p / 1024.0).rgb;
    float big_growth = smooth_noise(p * 0.00145 + vec2(8.0, 23.0));
    float damp = smooth_noise(p * 0.0047 + vec2(-7.5, 2.0));
    // Keep the painted image's colors. Stage-specific shader palette inputs
    // remain for compatibility with ChapterOneStage's older save/runtime API.
    base = mix(base, base * vec3(0.84, 1.11, 0.95), big_growth * 0.21);
    base = mix(base, base * vec3(0.87, 0.91, 1.04), damp * 0.09);

    // One naturally meandering world-space footpath, with blurred ragged edges.
    // Not an arena boundary. Combat and enemy movement remain unrestricted.
    float spine = 326.0 + sin(p.y * 0.00165) * 96.0
        + sin(p.y * 0.0036 + 1.7) * 37.0;
    float ragged = (smooth_noise(p * 0.0131 + 17.0) - 0.5) * 58.0;
    float distance_from_path = abs(p.x - spine + ragged);
    float path = 1.0 - smoothstep(96.0, 247.0, distance_from_path);
    float chipped = smooth_noise(p * 0.0093 + 9.8);
    vec3 old_stone = base * vec3(1.17, 1.17, 1.19);
    old_stone = mix(old_stone, vec3(0.225, 0.305, 0.277), 0.36);
    base = mix(base, old_stone, path * (0.38 + chipped * 0.20));

    // Moss at irregular roadside seams: deliberately organic, never a grid.
    float road_shoulder = smoothstep(115.0, 181.0, distance_from_path)
        * (1.0 - smoothstep(219.0, 298.0, distance_from_path));
    float overgrowth = smoothstep(0.53, 0.81, smooth_noise(p * 0.016 + 35.0));
    base = mix(base, mix(base, moss_jade.rgb * 1.74, 0.24),
        road_shoulder * overgrowth * 0.35);

    // No glow/pulsing circles here: bright attacks, drops and enemy outlines
    // must be perceptually distinct from environment imagery.
    float edge_distance = length(SCREEN_UV - vec2(0.5));
    float vignette = 1.0 - smoothstep(0.32, 0.72, edge_distance) * 0.15;
    base *= vignette;
    COLOR = vec4(clamp(base, vec3(0.0), vec3(1.0)), 1.0);
}
