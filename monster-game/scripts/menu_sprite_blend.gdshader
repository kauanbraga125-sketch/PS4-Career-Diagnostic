shader_type canvas_item;
uniform vec2 next_offset = vec2(0.0);
uniform float transition : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec4 a = texture(TEXTURE, UV);
    vec4 b = texture(TEXTURE, UV + next_offset);
    float alpha = mix(a.a, b.a, transition);
    vec3 premultiplied = mix(a.rgb * a.a, b.rgb * b.a, transition);
    COLOR = vec4(alpha > 0.0001 ? premultiplied / alpha : vec3(0.0), alpha) * vertex_tint;
}
