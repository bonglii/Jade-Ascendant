shader_type canvas_item;
render_mode unshaded, blend_mix;

// Verdant Qi Valley — ambient depth layer.
// Mobile-oriented: procedural mist + sparse Qi motes in a single fullscreen-visible draw.
// The center of the screen is intentionally clearer for combat readability.

uniform vec4 mist_color : source_color = vec4(0.055, 0.260, 0.190, 1.0);
uniform vec4 qi_color : source_color = vec4(0.170, 0.640, 0.500, 1.0);
uniform float mist_strength : hint_range(0.0, 0.25) = 0.075;
uniform float mote_strength : hint_range(0.0, 0.30) = 0.10;
uniform float spatial_scale : hint_range(0.25, 2.5) = 1.0;
uniform float motion_speed : hint_range(0.0, 2.0) = 0.75;
uniform float layer_phase : hint_range(0.0, 6.28318) = 0.0;

varying vec2 world_position;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void vertex() {
    world_position = VERTEX;
}

void fragment() {
    float t = TIME * 0.075 * motion_speed;
    vec2 p = world_position * (0.00145 * spatial_scale);

    // Broad intersecting ribbons: they read as valley mist rather than attack telegraphs.
    float ribbon_a = sin(p.x * 1.25 + sin(p.y * 0.82 + layer_phase) * 1.15 + t);
    float ribbon_b = sin(p.y * 1.05 - sin(p.x * 0.68 - layer_phase) * 0.92 - t * 0.73);
    float ribbon_c = sin((p.x + p.y) * 0.54 + t * 0.46 + layer_phase * 1.7);
    float mist_field = ribbon_a * 0.44 + ribbon_b * 0.34 + ribbon_c * 0.22;
    mist_field = mist_field * 0.5 + 0.5;
    float mist = smoothstep(0.48, 0.86, mist_field) * mist_strength;

    // Sparse world-space motes. Fixed cells prevent noisy shimmering while TIME only pulses them.
    vec2 mote_grid = world_position / (235.0 / max(spatial_scale, 0.25));
    vec2 mote_id = floor(mote_grid);
    vec2 mote_local = fract(mote_grid) - vec2(0.5);
    float seed = hash21(mote_id + vec2(19.0, 37.0) + floor(layer_phase * 11.0));
    vec2 mote_offset = vec2(
        hash21(mote_id + vec2(5.0, 13.0)) - 0.5,
        hash21(mote_id + vec2(31.0, 7.0)) - 0.5
    ) * 0.56;
    float mote_radius = length(mote_local - mote_offset);
    float mote_gate = step(0.885, seed);
    float mote_pulse = 0.58 + 0.42 * sin(TIME * (0.45 + seed * 0.30) + seed * 6.2831853);
    float mote = (1.0 - smoothstep(0.012, 0.050, mote_radius));
    mote *= mote_gate * mote_pulse * mote_strength;

    // Keep the player's usual screen-center focus clean even while the world atmosphere moves.
    float center_distance = length(SCREEN_UV - vec2(0.5));
    float combat_readability = mix(0.42, 1.0, smoothstep(0.12, 0.48, center_distance));
    mist *= combat_readability;
    mote *= mix(0.55, 1.0, smoothstep(0.10, 0.42, center_distance));

    vec3 final_color = mix(mist_color.rgb, qi_color.rgb, clamp(mote * 5.0, 0.0, 1.0));
    float final_alpha = clamp(mist + mote, 0.0, 0.19);
    COLOR = vec4(final_color, final_alpha);
}
