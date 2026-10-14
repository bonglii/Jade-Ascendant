shader_type canvas_item;
uniform vec4 accent : source_color = vec4(0.65,0.35,1.0,1.0);
varying vec4 cel_tint;
void vertex() { cel_tint = COLOR; }
void fragment() {
	vec4 px = texture(TEXTURE, UV);
	float luma = max(px.r, max(px.g, px.b));
	float gold = smoothstep(0.03,0.18,px.r-px.b) * smoothstep(0.06,0.22,px.g-px.b);
	vec3 qi = mix(accent.rgb*luma,vec3(luma),smoothstep(0.75,1.0,luma)*0.6);
	COLOR = cel_tint * vec4(mix(qi,px.rgb,gold),px.a);
}
