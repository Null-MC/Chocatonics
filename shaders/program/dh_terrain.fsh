#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec2 lmcoord;
	vec4 color;
	vec3 normalMat;
	flat int materialId;
} vIn;

uniform sampler2D noisetex;

uniform vec2 texelSize;
uniform float rainStrength;
uniform float rainWetness;
uniform float alphaTestRef;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform int framemod8;

#include "/lib/ign.glsl"
#include "/lib/material.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"
#include "/lib/color_transforms.glsl"


/* RENDERTARGETS: 8,9,10,11 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outSpecular;
layout(location = 3) out vec4 outWorld;

void main() {
	float noise = IGN_time(frameTimeCounter);
	vec3 normal = vIn.normalMat;

	vec2 taa_offset = taa_offsets[framemod8];
	vec3 viewPos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize / RENDER_SCALE, 1.0) - vec3(taa_offset * texelSize * 0.5, 0.0));

	float wetness = 0.0;
	if (rainStrength > 0.0 || rainWetness > 0.0) {
		vec3 localPos = mul3(gbufferModelViewInverse, viewPos);

		vec3 localNormal = mat3(gbufferModelViewInverse) * normal;
		float skyExposure = smoothstep((13.5/15.0), (14.5/15.0), vIn.lmcoord.y);
		float wetnessF = saturate(localNormal.y); //saturate(unmix(-0.4, 0.1, localTexNormal.y));

		vec2 texcoord = localPos.xz + cameraPosition.xz;
		float puddleF = smoothstep(0.06, 0.24, rainWetness * texture(noisetex, texcoord*0.05).g);

		wetness = skyExposure * max(rainStrength * wetnessF * 0.6, puddleF);
	}

	vec4 color = vIn.color;

	float smoothness = 0.0;
	const float f0 = 0.04;
	float emission = 0.0;
	float porosity = 0.85;
	float sss = 0.0;

	if (vIn.materialId == DH_BLOCK_LEAVES) sss = 0.5;
	if (vIn.materialId == DH_BLOCK_SNOW) sss = 0.2;
	if (vIn.materialId == DH_BLOCK_LAVA) emission = 0.8;
	if (vIn.materialId == DH_BLOCK_ILLUMINATED) emission = 1.0;

	if (wetness > 0.0) {
		vec3 albedo = toLinear(color.rgb) * (1.0 - 0.5 * wetness * porosity);
		albedo *= exp(-2.0 * wetness * porosity * (1.0 - albedo));
//		albedo *= (1.0 - 0.4 * wetness * porosity);

		smoothness = mix(smoothness, 1.0, smoothstep(0.0, 1.0, wetness));
		color.rgb = linearToSRGB(albedo);
	}

	const float mat = 0.0;

	outColor = color;
	outNormal = vec4(OctEncode(vIn.normalMat.xyz), OctEncode(normal));
	outSpecular = vec4(smoothness, f0, sss, emission);
	outWorld = vec4(vIn.lmcoord, 0.0, mat);
}
