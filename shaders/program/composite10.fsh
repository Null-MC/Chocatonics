#version 430 compatibility

// downsample 1st pass (half res) for bloom

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


uniform sampler2D colortex5;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;


/* RENDERTARGETS: 3 */
layout(location = 0) out vec3 outColor3;

void main() {
	vec2 resScale = max(vec2(viewWidth, viewHeight), vec2(1920.0, 1080.0)) / vec2(1920.0, 1080.0);
	vec2 quarterResTC = gl_FragCoord.xy * texelSize * 2.0 * resScale / BLOOM_QUALITY;

	// 1:2
	outColor3  = texture(colortex5, quarterResTC - vec2( texelSize.x, texelSize.y)).rgb/4.0*0.5;
	outColor3 += texture(colortex5, quarterResTC + vec2( texelSize.x, texelSize.y)).rgb/4.0*0.5;
	outColor3 += texture(colortex5, quarterResTC + vec2(-texelSize.x, texelSize.y)).rgb/4.0*0.5;
	outColor3 += texture(colortex5, quarterResTC + vec2( texelSize.x,-texelSize.y)).rgb/4.0*0.5;

	// 1:4
	outColor3 += texture(colortex5, quarterResTC-2.0*vec2(texelSize.x, 0.0)).rgb/2.0*0.125;
	outColor3 += texture(colortex5, quarterResTC+2.0*vec2(0.0, texelSize.y)).rgb/2.0*0.125;
	outColor3 += texture(colortex5, quarterResTC+2.0*vec2(0, -texelSize.y)).rgb/2.0*0.125;
	outColor3 += texture(colortex5, quarterResTC+2.0*vec2(-texelSize.x, 0.0)).rgb/2.0*0.125;

	// 1:8
	outColor3 += texture(colortex5, quarterResTC-2.0*vec2(texelSize.x, texelSize.y)).rgb/4.0*0.125;
	outColor3 += texture(colortex5, quarterResTC+2.0*vec2(texelSize.x, texelSize.y)).rgb/4.0*0.125;
	outColor3 += texture(colortex5, quarterResTC+vec2(-2.0*texelSize.x,2.0*texelSize.y)).rgb/4.0*0.125;
	outColor3 += texture(colortex5, quarterResTC+vec2(2.0*texelSize.x,-2.0*texelSize.y)).rgb/4.0*0.125;

	// 1:8
	outColor3 += texture(colortex5, quarterResTC).rgb * 0.125;

	outColor3 = clamp(outColor3, 0.0, 65000.0);

	if (quarterResTC.x > 1.0 - 3.5*texelSize.x || quarterResTC.y > 1.0 -3.5*texelSize.y || quarterResTC.x < 3.5*texelSize.x || quarterResTC.y < 3.5*texelSize.y) {
		outColor3 = vec3(0.0);
	}
}
