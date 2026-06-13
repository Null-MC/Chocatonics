#version 430 compatibility

// 6 Vertical gaussian blurs and vertical downsampling

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in vec2 texcoord;

uniform sampler2D colortex6;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;


vec2 resScale = vec2(1920.0,1080.0) / max(vec2(viewWidth, viewHeight), vec2(1920.0, 1080.0)) * BLOOM_QUALITY;

vec3 gauss1D(vec2 coord, vec2 dir, float alpha, int maxIT) {
	vec4 tot = vec4(0.0);
	float maxTC = 0.25 * resScale.y;
	float minTC = 0.0;

	for (int i = -maxIT; i < maxIT+1; i++) {
		float weight = exp(i*i * alpha * -4.0);
		vec2 spCoord = coord + dir * texelSize * (2.0 * i + 0.5);
		tot += vec4(texture(colortex6, spCoord).rgb, 1.0) * weight * float(spCoord.y > minTC && spCoord.y < maxTC);
	}

	return  tot.rgb / max(1.0, tot.a);
}


/* RENDERTARGETS: 6 */
layout(location = 0) out vec3 outColor6;

void main() {
	vec2 texcoord = (gl_FragCoord.xy * vec2(2.0, 4.0)) * texelSize;

	vec2 gaussDir = vec2(0.0, 1.0);
	outColor6 = vec3(0.0);

	vec2 tc2 = texcoord * vec2(2.0, 1.0);
	if (tc2.x < 1.0 * resScale.x && tc2.y < 1.0 * resScale.y)
		outColor6 = gauss1D(texcoord / vec2(2.0, 4.0), gaussDir, 0.16, 0);

	vec2 tc4 = texcoord * vec2(4.0, 2.0) - vec2(0.5 * resScale.x + 4.0 * texelSize.x, 0.0) * 4.0;
	if (tc4.x > 0.0 && tc4.y > 0.0 && tc4.x < 1.0 * resScale.x && tc4.y < 1.0 * resScale.y)
		outColor6 = gauss1D(texcoord / vec2(2.0, 2.0), gaussDir, 0.16, 3);

	vec2 tc8 = texcoord * vec2(8.0, 4.0) - vec2(0.75 * resScale.x + 8.0 * texelSize.x, 0.0) * 8.0;
	if (tc8.x > 0.0 && tc8.y > 0.0 && tc8.x < 1.0 * resScale.x && tc8.y < 1.0 * resScale.y)
		outColor6 = gauss1D(texcoord * vec2(1.0, 2.0) / vec2(2.0, 2.0), gaussDir, 0.035, 6);

	vec2 tc16 = texcoord * vec2(16.0, 8.0) - vec2(0.875 * resScale.x + 12.0 * texelSize.x, 0.0) * 16.0;
	if (tc16.x > 0.0 && tc16.y > 0.0 && tc16.x < 1.0 * resScale.x && tc16.y < 1.0 * resScale.y)
		outColor6 = gauss1D(texcoord * vec2(1.0, 4.0) / vec2(2.0, 2.0), gaussDir, 0.0085, 12);

	vec2 tc32 = texcoord * vec2(32.0, 16.0) - vec2(0.9375 * resScale.x + 16.0 * texelSize.x, 0.0) * 32.0;
	if (tc32.x > 0.0 && tc32.y > 0.0 && tc32.x < 1.0 * resScale.x && tc32.y < 1.0 * resScale.y)
		outColor6 = gauss1D(texcoord * vec2(1.0, 8.0) / vec2(2.0, 2.0), gaussDir, 0.002, 30);

	vec2 tc64 = texcoord * vec2(64.0, 32.0) - vec2(0.96875 * resScale.x + 20.0 * texelSize.x, 0.0) * 64.0;
	if (tc64.x > 0.0 && tc64.y > 0.0 && tc64.x < 1.0 * resScale.x && tc64.y < 1.0 * resScale.y)
		outColor6 = gauss1D(texcoord * vec2(1.0, 16.0) / vec2(2.0, 2.0), gaussDir, 0.0005, 60);

	outColor6 = clamp(outColor6, 0.0, 65000.0);
}
