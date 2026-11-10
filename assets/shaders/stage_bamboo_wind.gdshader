shader_type canvas_item;

uniform float quiet = 1.0;
uniform float phase = 0.0;

void vertex() {
	// Feet stay on the rock/earth while the upper canopy bends first.
	float canopy = pow(1.0 - UV.y, 2.2);
	float gust = sin(TIME * 0.34 + phase) * 0.65 + sin(TIME * 0.83 + phase * 2.0) * 0.35;
	VERTEX.x += canopy * gust * 12.0 * quiet;
	VERTEX.y += canopy * sin(TIME * 0.34 + phase) * 2.6 * quiet;
}
