shader_type canvas_item;
render_mode unshaded;

// One repeatable painted atlas sample per pixel. No fragment noise / GPU loops.
uniform sampler2D frost_floor : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR = vec4(texture(frost_floor, world_position / 768.0).rgb, 1.0);
}
