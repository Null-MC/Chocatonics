#version 120
#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_shader_texture_lod : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

uniform sampler2D texture;
uniform float frameTimeCounter;
uniform mat4 gbufferProjectionInverse;
uniform float alphaTestRef;

#include "/lib/ign.glsl"
#include "/lib/encoding.glsl"
//#include "/lib/projections.glsl"


/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 outColor1;

void main() {
	float noise = IGN_time(frameTimeCounter);
	vec3 normal = normalMat.xyz;

	vec4 data0 = texture2D(texture, lmtexcoord.xy);
	float avgBlockLum = luma(texture2DLod(texture, lmtexcoord.xy,128).rgb*color.rgb);

	data0.rgb = saturate(data0.rgb * pow(avgBlockLum, -0.33) * 0.85);
	#ifdef DISABLE_ALPHA_MIPMAPS
		data0.a = texture2DLod(texture, lmtexcoord.xy, 0).a;
	#endif

	data0.rgb *= color.rgb;

	if (data0.a < alphaTestRef) discard;
	data0.a = normalMat.a;

	vec4 data1 = saturate(noise / 256.0 + encode(normal));

	outColor1 = vec4(
		encodeVec2(data0.x, data1.x),
		encodeVec2(data0.y, data1.y),
		encodeVec2(data0.z, data1.z),
		encodeVec2(data1.w, data0.w));
}
