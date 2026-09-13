shader_type canvas_item;
render_mode unshaded;

uniform float pulse_strength : hint_range(0.0, 0.08) = 0.025;
uniform float pulse_speed : hint_range(0.1, 2.0) = 0.65;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float cyan_energy = clamp(
		(source.b - source.r) * 1.5 + (source.g - source.r) * 0.7,
		0.0,
		1.0
	);
	cyan_energy *= smoothstep(0.5, 1.0, max(source.g, source.b));
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	source.rgb += vec3(0.04, 0.28, 0.34)
		* cyan_energy
		* pulse
		* pulse_strength;
	COLOR = source;
}
