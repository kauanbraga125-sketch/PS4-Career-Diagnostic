shader_type sky;
render_mode use_quarter_res_pass, disable_fog;
uniform sampler2D day_sky : source_color, filter_linear_mipmap;
uniform sampler2D dawn_sky : source_color, filter_linear_mipmap;
uniform sampler2D night_sky : source_color, filter_linear_mipmap;
uniform sampler3D cloud_noise : repeat_enable, filter_linear;
uniform float daylight=1.0;
uniform float sunset=0.0;
uniform float cloudiness=0.35;
uniform float wind_time=0.0;
uniform bool volumetric=true;
void sky() {
	vec3 day=mix(texture(day_sky,SKY_COORDS).rgb,texture(dawn_sky,SKY_COORDS).rgb,sunset);
	vec3 base=mix(texture(night_sky,SKY_COORDS).rgb*.46+vec3(.018,.032,.060),day,daylight);
	base=mix(base,vec3(.43,.52,.64)*(.2+.8*daylight),cloudiness*.26);
	if (AT_CUBEMAP_PASS) { COLOR=base; }
	else if (AT_QUARTER_RES_PASS) {
		vec4 clouds=vec4(0.0);
		if (volumetric && abs(EYEDIR.y)>.025) {
			float a=(220.0-POSITION.y)/EYEDIR.y;
			float b=(300.0-POSITION.y)/EYEDIR.y;
			float near_t=max(0.0,min(a,b));
			float far_t=min(2500.0,max(a,b));
			if (far_t>near_t) {
				float step_length=(far_t-near_t)/12.0;
				for (int i=0;i<12;i++) {
					vec3 p=POSITION+EYEDIR*(near_t+(float(i)+.5)*step_length);
					vec3 coord=p*vec3(.0022,.006,.0022)+vec3(wind_time*.007,0.0,wind_time*.003);
					float noise=texture(cloud_noise,coord).r;
					float edge=smoothstep(220.0,240.0,p.y)*(1.0-smoothstep(280.0,300.0,p.y));
					float density=smoothstep(.57-cloudiness*.25,.77,noise)*edge;
					float alpha=1.0-exp(-density*step_length*.055);
					float top_light=clamp((p.y-220.0)/80.0,0.0,1.0);
					vec3 tint=mix(vec3(.32,.43,.57),vec3(1.0,.96,.87),top_light*.7+.3)*(.18+.82*daylight);
					clouds.rgb+=(1.0-clouds.a)*alpha*tint;
					clouds.a+=(1.0-clouds.a)*alpha;
				}
			}
		}
		COLOR=clouds.rgb/max(clouds.a,.001); ALPHA=clouds.a;
	} else { COLOR=mix(base,QUARTER_RES_COLOR.rgb,QUARTER_RES_COLOR.a); }
}
