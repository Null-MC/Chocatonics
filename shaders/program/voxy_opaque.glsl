#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#include "/lib/blocks.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/color_transforms.glsl"


/* RENDERTARGETS: 8,9,10,11 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outSpecular;
layout(location = 3) out vec4 outWorld;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	vec4 color = parameters.sampledColour;

	vec3 tint = parameters.tinting.rgb;
	if (parameters.customId == BLOCK_EMISSIVE) {
		tint = normalize(tint) * sqrt(3.0);
	}

	color.rgb *= tint;

	vec3 localNormal = vec3(
		uint((parameters.face >> 1) == 2),
		uint((parameters.face >> 1) == 0),
		uint((parameters.face >> 1) == 1)
	) * (float(int(parameters.face) & 1) * 2.0 - 1.0);

	vec3 viewNormal = mat3(gbufferModelView) * localNormal;

	// TODO: normalize?
	vec2 lmcoord = parameters.lightMap;

	const float roughness = 1.0;
	const float f0 = 0.04;
	float emission = 0.0;
	float sss = 0.0;

	float mat = (parameters.customId == BLOCK_SSS || parameters.customId == BLOCK_PLANT_WAVING_FULL || parameters.customId == BLOCK_PLANT_WAVING_TOP) ? 0.5 : 1.0;

	if (parameters.customId == BLOCK_IDK) mat = 0.6;

	if (parameters.customId == BLOCK_EMISSIVE) {
		mat = 0.9;
	}

	if (mat < 0.51) {
		sss = 0.5;
	}
	else if (mat < 0.61) {
		sss = 0.2;
	}
	else if (mat < 0.91) {
		vec3 albedo = InputTransform(color.rgb);
		emission = saturate(luma(albedo) * 3.0);
	}

	outColor = color;
	outNormal = vec4(OctEncode(viewNormal), OctEncode(viewNormal));
	outSpecular = vec4(roughness, f0, sss, emission);
	outWorld = vec4(lmcoord, 0.0, 1.0);
}
