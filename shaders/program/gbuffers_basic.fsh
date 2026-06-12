#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

uniform sampler2D texture;

uniform float frameTimeCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float alphaTestRef;

#include "/lib/ign.glsl"
#include "/lib/encoding.glsl"
#include "/lib/projections.glsl"


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 outColor1;

void main() {
	float noise = IGN_time(frameTimeCounter);
	vec3 normal = normalMat.xyz;

	vec4 data0 = color;
	float avgBlockLum = luma(color.rgb);
	data0.rgb = saturate(data0.rgb * pow(avgBlockLum, -0.33) * 0.85);
	data0.a = float(data0.a > noise);

	if (data0.a < alphaTestRef) discard;
	data0.a = normalMat.a * 0.5 + 0.5;

	vec4 data1 = saturate(encode(normal, lmtexcoord.zw));

	outColor1 = vec4(
		encodeVec2(data0.x, data1.x),
		encodeVec2(data0.y, data1.y),
		encodeVec2(data0.z, data1.z),
		encodeVec2(data1.w, data0.w));
}
