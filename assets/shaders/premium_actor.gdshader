shader_type canvas_item;
render_mode unshaded;
uniform vec4 accent : source_color = vec4(0.36,0.95,0.81,1.0);
uniform vec4 frame_uv = vec4(0.0,0.0,1.0,1.0);
uniform float energy : hint_range(0.0,1.0) = 0.0;
uniform float rim_strength : hint_range(0.0,1.0) = 0.65;
varying vec4 actor_tint;
void vertex() { actor_tint = COLOR; }
float region_alpha(sampler2D source, vec2 uv) {
 if (uv.x < frame_uv.x || uv.y < frame_uv.y || uv.x > frame_uv.z || uv.y > frame_uv.w) { return 0.0; }
 return texture(source,uv).a;
}
void fragment() {
 vec4 tex = texture(TEXTURE,UV);
 vec2 p = TEXTURE_PIXEL_SIZE;
 float a = region_alpha(TEXTURE,UV+vec2(p.x,0.0));
 float b = region_alpha(TEXTURE,UV-vec2(p.x,0.0));
 float c = region_alpha(TEXTURE,UV+vec2(0.0,p.y));
 float d = region_alpha(TEXTURE,UV-vec2(0.0,p.y));
 float outside = max(max(a,b),max(c,d)) * (1.0-tex.a);
 float inside = (1.0-min(min(a,b),min(c,d))) * tex.a;
 vec3 body = (tex.rgb-vec3(0.5))*1.08+vec3(0.5);
 body += accent.rgb * inside * 0.20 * rim_strength;
 body += accent.rgb * energy * tex.a * 0.11;
 vec3 rgb = mix(accent.rgb,body,tex.a);
 float alpha = max(tex.a,outside * rim_strength * 0.72);
 COLOR = vec4(rgb,alpha) * actor_tint;
}
