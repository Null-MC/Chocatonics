#define DRAW_SUN //if not using custom sky
#define SKY_BRIGHTNESS_DAY 1.0 //[0.0 0.5 0.75 1. 1.2 1.4 1.6 1.8 2.0]
#define SKY_BRIGHTNESS_NIGHT 1.0 //[0.0 0.5 0.75 1. 1.2 1.4 1.6 1.8 2.0]
#define ffstep(x,y) saturate((y - x) * 1e35)


vec3 drawSun(float cosY, float sunInt, vec3 nsunlight, vec3 inColor){
	return inColor + nsunlight/0.0008821203 * pow(smoothstep(cos(0.0093084168595*3.2), cos(0.0093084168595*1.8), cosY), 3.0) * 0.62;
}

vec2 sphereToCarte(vec3 dir) {
    float lonlat = atan(-dir.x, -dir.z);
    return vec2(lonlat * (0.5/PI) + 0.5, dir.y * 0.5 + 0.5);
}

vec3 skyFromTex(vec3 pos, sampler2D sampler) {
	vec2 p = sphereToCarte(pos);
	return texture(sampler, p * texelSize * 256.0 + vec2(18.5, 1.5) * texelSize).rgb;
}

vec4 texture2D_bicubic(sampler2D tex, vec2 uv) {
	vec4 texelSize = vec4(texelSize, 1.0 / texelSize);
	uv = uv * texelSize.zw;

	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * texelSize.xy;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * texelSize.xy;

    return g0(fuv.y) * (g0x * texture(tex, p0)  +
                        g1x * texture(tex, p1)) +
           g1(fuv.y) * (g0x * texture(tex, p2)  +
                        g1x * texture(tex, p3));
}

vec4 skyCloudsFromTex(vec3 pos, sampler2D sampler) {
	vec2 p = sphereToCarte(pos);
	return texture(sampler, p * texelSize * 256.0 + vec2(18.5 + 257.0, 1.5) * texelSize);
}
