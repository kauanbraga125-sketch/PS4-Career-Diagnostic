shader_type canvas_item;
render_mode blend_premul_alpha;

uniform sampler2D body_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D face_a : source_color, filter_nearest, repeat_disable;
uniform sampler2D face_b : source_color, filter_nearest, repeat_disable;
uniform vec2 face_origin_a;
uniform vec2 face_origin_b;
uniform float face_blend = 0.0;
uniform vec2 body_translation;
uniform float head_angle = 0.0;
varying vec4 vertex_tint;

float ease(float value) {
    float t = clamp(value, 0.0, 1.0);
    return t*t*t*(t*(t*6.0-15.0)+10.0);
}

vec4 premul_sample(sampler2D tex, vec2 point) {
    ivec2 limit = textureSize(tex,0)-ivec2(1);
    ivec2 p = ivec2(floor(point));
    vec2 f = fract(point);
    vec4 a = texelFetch(tex,clamp(p,ivec2(0),limit),0);
    vec4 b = texelFetch(tex,clamp(p+ivec2(1,0),ivec2(0),limit),0);
    vec4 c = texelFetch(tex,clamp(p+ivec2(0,1),ivec2(0),limit),0);
    vec4 d = texelFetch(tex,clamp(p+ivec2(1,1),ivec2(0),limit),0);
    a.rgb *= a.a; b.rgb *= b.a; c.rgb *= c.a; d.rgb *= d.a;
    return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

void vertex() { vertex_tint = COLOR; }

void fragment() {
    vec2 point = UV*512.0-vec2(.5);
    vec2 source = point;
    for (int i=0;i<2;i++) {
        float weight = ease((439.0-source.y)/180.0);
        float a = head_angle*ease((285.0-source.y)/48.0);
        vec2 o = point-vec2(280.0,245.0)-body_translation*weight;
        source = vec2(280.0,245.0)+vec2(cos(a)*o.x+sin(a)*o.y,-sin(a)*o.x+cos(a)*o.y);
    }
    vec4 color = premul_sample(body_texture,source);
    vec2 q = source-vec2(256.0,151.0);
    if (q.x>=0.0 && q.y>=0.0 && q.x<=111.0 && q.y<=111.0) {
        vec4 face = premul_sample(face_a,face_origin_a+q);
        if (face_blend>0.00001) face = mix(face,premul_sample(face_b,face_origin_b+q),face_blend);
        float edge = min(min(q.x,q.y),min(111.0-q.x,111.0-q.y));
        color = mix(color,face,smoothstep(0.0,2.0,edge));
    }
    COLOR = color*vec4(vertex_tint.rgb*vertex_tint.a,vertex_tint.a);
}
