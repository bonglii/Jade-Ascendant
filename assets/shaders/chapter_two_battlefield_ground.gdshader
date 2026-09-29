shader_type canvas_item;
render_mode unshaded;

uniform sampler2D crimson_floor : source_color, repeat_enable, filter_linear;
uniform vec4 deep_earth : source_color = vec4(0.105, 0.022, 0.033, 1.0);
uniform vec4 moss_jade : source_color = vec4(0.240, 0.060, 0.070, 1.0);
uniform vec4 wet_stone : source_color = vec4(0.135, 0.055, 0.060, 1.0);
uniform vec4 qi_jade : source_color = vec4(0.620, 0.155, 0.120, 1.0);
uniform vec4 qi_cyan : source_color = vec4(0.700, 0.250, 0.140, 1.0);

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
    vec3 base = texture(crimson_floor, p / 1024.0).rgb;
    float ash = smooth_noise(p * 0.0017 + vec2(21.0, 4.0));
    float cinder = smooth_noise(p * 0.0048 + vec2(-6.0, 3.0));
    base = mix(base, base * vec3(0.96, 0.85, 0.88), ash * 0.20);
    base = mix(base, base * vec3(1.10, 0.96, 0.92), cinder * 0.07);

    float spine = 326.0 + sin(p.y * 0.00142 + 0.9) * 85.0
        + sin(p.y * 0.0031 + 0.2) * 28.0;
    float ragged = (smooth_noise(p * 0.012 + 13.0) - 0.5) * 62.0;
    float distance_from_path = abs(p.x - spine + ragged);
    float avenue = 1.0 - smoothstep(102.0, 250.0, distance_from_path);
    float chipped = smooth_noise(p * 0.009 + 3.6);
    vec3 old_stone = base * vec3(1.10, 0.93, 0.94);
    old_stone = mix(old_stone, vec3(0.23, 0.13, 0.14), 0.44);
    base = mix(base, old_stone, avenue * (0.34 + chipped * 0.22));

    float shoulder = smoothstep(126.0, 180.0, distance_from_path)
        * (1.0 - smoothstep(225.0, 316.0, distance_from_path));
    float glow = smoothstep(0.60, 0.86, smooth_noise(p * 0.016 + 8.0));
    vec3 ember = mix(vec3(0.27, 0.05, 0.05), qi_jade.rgb * 1.15, 0.55);
    base = mix(base, mix(base, ember, 0.42), shoulder * glow * 0.28);

    float edge_distance = length(SCREEN_UV - vec2(0.5));
    float vignette = 1.0 - smoothstep(0.32, 0.74, edge_distance) * 0.16;
    base *= vignette;
    COLOR = vec4(clamp(base, vec3(0.0), vec3(1.0)), 1.0);
}
