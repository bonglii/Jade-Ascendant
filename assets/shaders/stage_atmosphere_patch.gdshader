shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 tint : source_color = vec4(0.36, 0.73, 0.56, 1.0);
uniform vec2 wind = vec2(0.9, 0.25);
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform int motif = 0;
uniform bool reduced = false;

float hash_cell(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = 1.0 - smoothstep(0.16, 0.65, length(p * vec2(1.12, 1.32)));
	float time = TIME * 0.34 + seed;
	float breath = 0.76 + 0.24 * sin(time * 0.59 + p.x * 4.0);
	float detail = 0.0;
	float light = 0.0;

	if (motif == 1 || motif == 3 || motif == 5) {
		// Silk-like strips follow the local wind with distinct widths and breaks.
		float flow = dot(p, wind);
		float across = dot(p, vec2(-wind.y, wind.x));
		float folds = sin(flow * 8.0 - time + seed) * 0.09;
		float ribbon = exp(-abs(across - folds) * (motif == 3 ? 36.0 : 12.0));
		float second = exp(-abs(across + 0.20 + folds * 0.8) * 24.0);
		light = (ribbon * (motif == 1 ? 0.48 : 0.31) + second * 0.17) * breath;
	} else if (motif == 2 || motif == 4) {
		// Emission from fissures and lantern feet stays fixed to the prop.
		vec2 q = p + vec2(0.06, -0.03);
		float cut = abs(q.y + q.x * 0.34 + sin(q.x * 16.0) * 0.026);
		float branch = abs(q.y - q.x * 0.37 + 0.015);
		float inner = exp(-length(q * vec2(2.1, 3.0)) * 2.1);
		float fissure = 0.74 * exp(-cut * 64.0) + 0.32 * exp(-branch * 79.0);
		light = inner * (motif == 2 ? fissure + 0.24 : 0.44) * breath;
	} else if (motif == 6) {
		float ripple = sin(p.y * 45.0 + sin(p.x * 11.0 - time) * 1.6 - time * 2.0);
		light = pow(max(ripple, 0.0), 4.0) * exp(-abs(p.y) * 9.0) * 0.23;
	} else {
		light = exp(-length(p * vec2(2.2, 3.2)) * 4.2) * (motif == 0 ? 0.22 : 0.16) * breath;
	}

	if (!reduced) {
		vec2 direction = wind;
		if (motif == 7 || motif == 9) {
			direction = vec2(wind.x * 0.35, -0.76);
		}
		vec2 grid = (UV - direction * TIME * (motif == 3 ? 0.075 : 0.040)) * vec2(8.0, 6.0);
		vec2 id = floor(grid);
		float random = hash_cell(id + vec2(seed * 7.0, 2.0));
		vec2 within = fract(grid) - 0.5;
		within -= vec2(random - 0.5, hash_cell(id + 9.0) - 0.5) * 0.52;
		// Pollen is round. Wind and bamboo carry slender leaves. Snow falls as fine flakes.
		vec2 aspect = motif == 1 || motif == 3 || motif == 5 ? vec2(0.55, 2.2) : vec2(1.0, 1.3);
		float shape = 1.0 - smoothstep(0.055, 0.20, length(within * aspect));
		float glint = 0.70 + 0.30 * sin(time * 2.0 + random * 15.0);
		detail = shape * step(0.72, random) * glint * (motif == 9 || motif == 7 ? 0.64 : 0.48);
	}
	vec3 color = mix(tint.rgb, vec3(0.94, 0.93, 0.79), min(0.55, detail));
	COLOR = vec4(color, min(0.46, (light + detail) * edge * strength));
}
