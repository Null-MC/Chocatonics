#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

uniform sampler2D texture;
uniform sampler2D gaux1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;

#include "/lib/projections.glsl"


float calcDistort(vec2 worlpos) {
	vec2 pos = worlpos * 1.165;
	vec2 posSQ = pos * pos;

	float distb = pow(posSQ.x*posSQ.x*posSQ.x + posSQ.y*posSQ.y*posSQ.y, 1.0 / 6.0);
	return 1.08695652 / ((1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS);
}


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture2D(texture, lmtexcoord.xy);

	vec3 albedo = toLinear(outColor2.rgb * color.rgb);

	float exposure = texelFetch2D(gaux1, ivec2(10, 37), 0).r;

	vec3 col = albedo * exp(exposure * -3.0);

	outColor2.rgb = col * color.a;
	outColor2.a = outColor2.a * 0.1;
}
