shader_type canvas_item;
render_mode unshaded;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
    vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
    vec4 base = texture(TEXTURE, UV);
    float edge = max(max(texture(TEXTURE,UV+vec2(px.x,0.0)).a,texture(TEXTURE,UV-vec2(px.x,0.0)).a),max(texture(TEXTURE,UV+vec2(0.0,px.y)).a,texture(TEXTURE,UV-vec2(0.0,px.y)).a));
    float inner = min(texture(TEXTURE,UV+vec2(px.x,px.y)).a,texture(TEXTURE,UV-vec2(px.x,px.y)).a);
    vec3 ink = vec3(0.075,0.041,0.105);
    vec3 rgb = mix(ink,base.rgb + (1.0-inner)*0.07,base.a);
    COLOR = vec4(rgb*vertex_tint.rgb,max(base.a,edge)*vertex_tint.a);
}
