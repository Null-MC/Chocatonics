#version 120

// downsample 1st pass (half res) for bloom

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

uniform sampler2D colortex3;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;


/* RENDERTARGETS: 6 */
layout(location = 0) out vec3 outColor6;

void main() {
	vec2 resScale = max(vec2(viewWidth, viewHeight), vec2(1920.0, 1080.0)) / vec2(1920.0, 1080.0);
	vec2 quarterResTC = gl_FragCoord.xy * texelSize * 2.0;

	// 1:2
	outColor6  = texture2D(colortex3, quarterResTC - vec2( texelSize.x, texelSize.y)).rgb /4.0 *0.5;
	outColor6 += texture2D(colortex3, quarterResTC + vec2( texelSize.x, texelSize.y)).rgb /4.0 *0.5;
	outColor6 += texture2D(colortex3, quarterResTC + vec2(-texelSize.x, texelSize.y)).rgb /4.0 *0.5;
	outColor6 += texture2D(colortex3, quarterResTC + vec2( texelSize.x,-texelSize.y)).rgb /4.0 *0.5;

	// 1:4
	outColor6 += texture2D(colortex3, quarterResTC-2.0*vec2(texelSize.x,0.0)).rgb/2.*0.125;
	outColor6 += texture2D(colortex3, quarterResTC+2.0*vec2(0.0,texelSize.y)).rgb/2.*0.125;
	outColor6 += texture2D(colortex3, quarterResTC+2.0*vec2(0,-texelSize.y)).rgb/2*0.125;
	outColor6 += texture2D(colortex3, quarterResTC+2.0*vec2(-texelSize.x,0.0)).rgb/2*0.125;

	// 1:8
	outColor6 += texture2D(colortex3, quarterResTC-2.0*vec2(texelSize.x,texelSize.y)).rgb/4.*0.125;
	outColor6 += texture2D(colortex3, quarterResTC+2.0*vec2(texelSize.x,texelSize.y)).rgb/4.*0.125;
	outColor6 += texture2D(colortex3, quarterResTC+vec2(-2.0*texelSize.x,2.0*texelSize.y)).rgb/4.*0.125;
	outColor6 += texture2D(colortex3, quarterResTC+vec2(2.0*texelSize.x,-2.0*texelSize.y)).rgb/4.*0.125;

	// 1:8
	outColor6 += texture2D(colortex3, quarterResTC).rgb * 0.125;

	outColor6 = clamp(outColor6, 0.0, 65000.0);
}
