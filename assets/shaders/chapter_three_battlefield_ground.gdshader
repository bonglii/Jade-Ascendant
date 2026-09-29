shader_type canvas_item;
render_mode unshaded;

// Chapter 3: world-space sky-palace flagstones under every gameplay effect.
// No animated circles/telegraphs. Same biome for stages 3-1 through 3-5.
uniform sampler2D celestial_floor : source_color, repeat_enable, filter_linear;
uniform vec4 deep_earth : source_color = vec4(0.018, 0.025, 0.070, 1.0);
uniform vec4 moss_jade : source_color = vec4(0.090, 0.120, 0.225, 1.0);
uniform vec4 wet_stone : source_color = vec4(0.165, 0.190, 0.285, 1.0);
uniform vec4 qi_jade : source_color = vec4(0.560, 0.670, 0.940, 1.0);
uniform vec4 qi_cyan : source_color = vec4(0.720, 0.790, 0.990, 1.0);

varying vec2 world_position;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float smooth_noise(vec2 p) {
    vec2 c = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x),
        mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void vertex() {
    world_position = VERTEX;
}

void fragment() {
    vec2 p = world_position;
    vec3 base = texture(celestial_floor, p / 1024.0).rgb;
    float cloud = smooth_noise(p * 0.0015 + vec2(4.0, 19.0));
    float stone = smooth_noise(p * 0.0051 + vec2(-8.0, 2.0));
    base = mix(base, base * vec3(0.91, 1.00, 1.11), cloud * 0.16);
    base = mix(base, base * vec3(0.96, 0.97, 1.05), stone * 0.08);

    // World-space sky-palace avenue. Subtle enough for clear attack telegraphs.
    float spine = 326.0 + sin(p.y * 0.00150 + 0.3) * 82.0
        + sin(p.y * 0.00330 + 1.5) * 33.0;
    float irregular = (smooth_noise(p * 0.0127 + 11.0) - 0.5) * 57.0;
    float distance_from_path = abs(p.x - spine + irregular);
    float path = 1.0 - smoothstep(109.0, 261.0, distance_from_path);
    float chipped = smooth_noise(p * 0.0095 + 2.9);
    vec3 aged_marble = mix(base * vec3(1.10, 1.10, 1.06),
        vec3(0.53, 0.59, 0.68), 0.40);
    base = mix(base, aged_marble, path * (0.28 + chipped * 0.20));

    float shoulder = smoothstep(130.0, 185.0, distance_from_path)
        * (1.0 - smoothstep(233.0, 305.0, distance_from_path));
    float gilt = smoothstep(0.55, 0.86, smooth_noise(p * 0.0158 + 37.0));
    base = mix(base, vec3(0.63, 0.58, 0.42), shoulder * gilt * 0.085);

    float edge_distance = length(SCREEN_UV - vec2(0.5));
    float vignette = 1.0 - smoothstep(0.34, 0.73, edge_distance) * 0.11;
    base *= vignette;
    COLOR = vec4(clamp(base, vec3(0.0), vec3(1.0)), 1.0);
}
