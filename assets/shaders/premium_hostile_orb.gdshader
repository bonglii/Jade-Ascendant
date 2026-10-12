shader_type canvas_item;
render_mode unshaded;
uniform vec4 emission : source_color = vec4(0.2,0.9,0.7,1.0);
uniform vec4 core : source_color = vec4(0.88,1.0,0.90,1.0);
varying vec4 orb_tint;
void vertex() { orb_tint = COLOR; }
void fragment() {
 vec4 tex = texture(TEXTURE,UV);
 float luma = dot(tex.rgb,vec3(0.2126,0.7152,0.0722));
 vec3 color = mix(emission.rgb*0.35,emission.rgb,luma);
 color = mix(color,core.rgb,smoothstep(0.70,1.0,luma));
 COLOR = vec4(color,tex.a)*orb_tint;
}
