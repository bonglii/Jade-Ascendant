shader_type canvas_item;
render_mode unshaded;
uniform vec4 accent : source_color = vec4(0.36,0.95,0.81,1.0);
uniform vec4 frame_uv = vec4(0.0,0.0,1.0,1.0);
uniform float energy : hint_range(0.0,1.0) = 0.0;
uniform float rim_strength : hint_range(0.0,1.0) = 0.65;
uniform float stride_phase = 0.0;
uniform float stride_strength = 0.0;
uniform float side_facing = 0.0;
varying vec4 actor_tint;
void vertex() { actor_tint = COLOR; }
float frame_mask(vec2 uv) {
 return step(frame_uv.x,uv.x)*step(frame_uv.y,uv.y)*step(uv.x,frame_uv.z)*step(uv.y,frame_uv.w);
}
void fragment() {
 vec2 frame_size = frame_uv.zw - frame_uv.xy;
 vec2 local_uv = (UV - frame_uv.xy) / max(frame_size, vec2(0.00001));
 float hem = smoothstep(0.54, 0.79, local_uv.y);
 float sway = sin(stride_phase + local_uv.y * 2.2) * 1.6 * stride_strength * hem;
 vec2 sample_uv = UV + vec2(sway * TEXTURE_PIXEL_SIZE.x, sin(stride_phase) * (local_uv.x - 0.5) * hem * stride_strength * (1.0 - side_facing) * TEXTURE_PIXEL_SIZE.y * 2.2);
 vec4 tex = texture(TEXTURE, clamp(sample_uv, frame_uv.xy + TEXTURE_PIXEL_SIZE * 0.5, frame_uv.zw - TEXTURE_PIXEL_SIZE * 0.5));
 tex.a *= frame_mask(sample_uv);
 vec2 p = TEXTURE_PIXEL_SIZE;
 float a = texture(TEXTURE,sample_uv+vec2(p.x,0.0)).a * frame_mask(sample_uv+vec2(p.x,0.0));
 float b = texture(TEXTURE,sample_uv-vec2(p.x,0.0)).a * frame_mask(sample_uv-vec2(p.x,0.0));
 float c = texture(TEXTURE,sample_uv+vec2(0.0,p.y)).a * frame_mask(sample_uv+vec2(0.0,p.y));
 float d = texture(TEXTURE,sample_uv-vec2(0.0,p.y)).a * frame_mask(sample_uv-vec2(0.0,p.y));
 float outside = max(max(a,b),max(c,d)) * (1.0-tex.a);
 float inside = (1.0-min(min(a,b),min(c,d))) * tex.a;
 vec3 body = (tex.rgb-vec3(0.5))*1.08+vec3(0.5);
 body += accent.rgb * inside * 0.20 * rim_strength;
 body += accent.rgb * energy * tex.a * 0.11;
 vec3 rgb = mix(accent.rgb,body,tex.a);
 float alpha = max(tex.a,outside * rim_strength * 0.72);
 COLOR = vec4(rgb,alpha) * actor_tint;
}
