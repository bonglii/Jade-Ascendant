shader_type canvas_item;
render_mode unshaded;

// Verdant Qi Valley — Stage 1 world-ground identity pass.
// Intentionally low-contrast so combat silhouettes remain readable on mobile.

uniform vec4 deep_earth : source_color = vec4(0.020, 0.067, 0.061, 1.0);
uniform vec4 moss_jade : source_color = vec4(0.041, 0.145, 0.108, 1.0);
uniform vec4 wet_stone : source_color = vec4(0.028, 0.087, 0.083, 1.0);
uniform vec4 qi_jade : source_color = vec4(0.120, 0.520, 0.365, 1.0);
uniform vec4 qi_cyan : source_color = vec4(0.120, 0.430, 0.430, 1.0);

varying vec2 ground_position;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float terrain_noise(vec2 p) {
    float result = 0.0;
    result += value_noise(p) * 0.56;
    result += value_noise(p * 2.03 + vec2(7.1, 3.7)) * 0.29;
    result += value_noise(p * 4.07 + vec2(2.6, 9.2)) * 0.15;
    return result;
}

void vertex() {
    ground_position = VERTEX;
}

void fragment() {
    vec2 world_p = ground_position;
    vec2 terrain_p = world_p * 0.0027;

    float broad = terrain_noise(terrain_p);
    float detail = value_noise(world_p * 0.012 + vec2(4.0, 11.0));
    float damp = terrain_noise(terrain_p * 0.54 + vec2(18.0, -6.0));

    vec3 base = mix(deep_earth.rgb, moss_jade.rgb, smoothstep(0.30, 0.78, broad));
    base = mix(base, wet_stone.rgb, smoothstep(0.67, 0.91, damp) * 0.34);
    base *= mix(0.90, 1.05, detail);

    // Sparse mineral/Qi veins. They are deliberately subdued to avoid visual noise.
    float vein_field = abs(value_noise(terrain_p * 3.1 + vec2(21.0, 5.0)) - 0.5);
    float vein = (1.0 - smoothstep(0.025, 0.095, vein_field));
    vein *= smoothstep(0.43, 0.82, broad) * 0.18;
    base += qi_jade.rgb * vein;

    // Very slow spiritual current gives the valley life without reading as an attack VFX.
    float flow = sin(world_p.x * 0.0065 + world_p.y * 0.0034 + broad * 7.0 + TIME * 0.18);
    flow = smoothstep(0.93, 1.0, flow) * smoothstep(0.48, 0.86, broad) * 0.055;
    base += qi_cyan.rgb * flow;

    // Rare, faint cultivation formation remnants distributed in world-space cells.
    vec2 rune_grid = world_p / 1180.0;
    vec2 rune_id = floor(rune_grid);
    vec2 rune_local = fract(rune_grid) - vec2(0.5);
    float rune_seed = hash21(rune_id + vec2(31.0, 17.0));
    float rune_radius = length(rune_local);
    float rune_ring = 1.0 - smoothstep(0.010, 0.026, abs(rune_radius - 0.175));
    rune_ring *= step(0.84, rune_seed) * 0.075;
    base += mix(qi_jade.rgb, qi_cyan.rgb, rune_seed) * rune_ring;

    // Screen-space falloff helps keep characters readable near the visual focus.
    vec2 screen_delta = SCREEN_UV - vec2(0.5);
    float edge = smoothstep(0.76, 0.18, length(screen_delta));
    base *= mix(0.82, 1.0, edge);

    COLOR = vec4(base, 1.0);
}
