#version 430 compatibility

// Photonics world-space reflections

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	flat vec4 lightCol;
//	flat vec3 ambientUp;
//	flat vec3 ambientLeft;
//	flat vec3 ambientRight;
//	flat vec3 ambientDown;
//	flat vec3 ambientB;
//	flat vec3 ambientF;
////	flat float tempOffsets;
	flat vec2 TAA_Offset;
//	flat float fogAmount;
//	flat float VFAmount;
//	flat vec3 refractedSunVec;
	flat vec3 WsunVec;
} vIn;

//uniform sampler2D TEX_GB_COLOR;
//uniform sampler2D TEX_GB_NORMAL;
//uniform sampler2D TEX_GB_SPECULAR;
//uniform sampler2D TEX_GB_WORLD;
uniform sampler2D noisetex;
//uniform sampler2D texBlueNoise;
uniform sampler2D depthtex0;
//uniform sampler2DShadow shadowtex0HW;
//uniform sampler2D colortex2;
uniform sampler2D colortex3;
//uniform sampler2D colortex4;
uniform sampler2D colortex13;

uniform float far;
uniform float near;
//uniform vec3 sunVec;
uniform int frameCounter;
//uniform float rainStrength;
//uniform float sunElevation;
//uniform ivec2 eyeBrightnessSmooth;
//uniform float frameTimeCounter;
//uniform int isEyeInWater;
uniform vec2 texelSize;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
////uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

#include "/lib/r2.glsl"
#include "/lib/ggx.glsl"
//#include "/lib/ign.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/octohedral.glsl"
//#include "/lib/waterOptions.glsl"
//#include "/lib/Shadow_Params.glsl"
//#include "/lib/color_transforms.glsl"
//#include "/lib/color_dither.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
//#include "/lib/volumetricClouds.glsl"


/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor3;

void main() {
	vec2 texcoord = gl_FragCoord.xy * texelSize;
	float z = texture(depthtex0, texcoord).x;

	ivec2 uv = ivec2(gl_FragCoord.xy);
	vec3 dest_color = texelFetch(colortex3, uv, 0).rgb;

	if (z < 1.0) {
//		vec3 fragpos = toScreenSpace(vec3(texcoord / RENDER_SCALE - vIn.TAA_Offset * texelSize * 0.5, z));
//		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
//		vec3 np3 = normVec(p3);

//		p3 += gbufferModelViewInverse[3].xyz;

//		vec4 color = texture(TEX_GB_COLOR, texcoord);
//		vec3 albedo = toLinear(color.rgb);

//		vec4 normalData = texture(TEX_GB_NORMAL, texcoord);
//		vec3 geo_normal = mat3(gbufferModelViewInverse) * OctDecode(normalData.xy);
//		vec3 tex_normal = OctDecode(normalData.zw);

//		vec3 normal = mat3(gbufferModelViewInverse) * tex_normal;

//		vec4 specularData = texture(TEX_GB_SPECULAR, texcoord);

//		vec4 worldData = texture(TEX_GB_WORLD, texcoord);
//		vec2 lightmap = worldData.xy;
//		float mat = worldData.w;

//		bool hand = abs(mat-0.75) < 0.01;

//		#ifdef MC_TEXTURE_FORMAT_LAB_PBR
//			float roughness = square(1.0 - specularData.r);
//			float f0 = specularData.g;
//			if (f0 < EPSILON) f0 = 0.04;
//		#else
//			float roughness = 1.0;
//			float f0 = 0.04;
//		#endif

//		vec3 diffuse = shading * diffuseSun;
//		MaterialReflections(dest_color, roughness, vec3(f0), albedo, vIn.WsunVec, vIn.lightCol.rgb, shading * diffuseSun, lightmap.y, normal, np3, fragpos, vec3(noise2, noise), hand);

//		vec3 Reflections_Final = dest_color;
//		float Outdoors = saturate(sqrt(lightmap.y - sky_occlusion_threshold) * (sky_occlusion_threshold * 5.0 + 1.0));

//		mat3 basis = CoordBase(normal);
//		vec3 normSpaceView = -np3 * basis;

//		// roughness stuff
//		#ifdef REFLECTION_ROUGH
//			vec2 noise2 = blueNoise(texBlueNoise, gl_FragCoord.xy).rg;
//
//			int seed = (frameCounter % 40000) * 2 + frameCounter + 1;
//			vec2  ij = fract(R2_samples(seed) + noise2);
//
//			vec3 H = sampleGGXVNDF(normSpaceView, vec2(roughness), ij.x, ij.y, hand);
//
//			if (hand) H = normalize(vec3(0.0, 0.0, 1.0));
//		#else
//			vec3 H = normalize(vec3(0.0, 0.0, 1.0));
//		#endif

//		vec3 Ln = reflect(-normSpaceView, clamp(H, -1.0, 1.0));
//		vec3 L = basis * Ln;

		// fresnel stuff
//		float fresnel = pow5(saturate(1.0 + dot(-Ln, H)));
//		vec3 F = vec3(f0 + (1.0 - f0) * fresnel);
//		vec3 rayContrib = F;

//		float NdotV = saturate(dot(np3, normalize(normal)) * 5000.0);

//		bool hasReflections = (f0 * (1.0 - roughness * Roughness_Threshold)) > 0.02;
//		if (!hasReflections || NdotV > 0.00001) Outdoors = 0.0;

		// SSR, Sky, and Sun reflections
		vec4 Reflections = vec4(0.0);
//		vec3 SkyReflection = skyCloudsFromTex(L, colortex4).rgb * 0.035;
//		vec3 SunReflection = diffuse * GGX2(normal, -np3,  vIn.WsunVec, roughness, vec3(f0))/150.0 * 8.0/3.0 * vIn.lightCol.rgb * Sun_specular_Strength;

//		if (hasReflections && NdotV < 0.00001) { // Skip SSR if ray contribution is low
//		if (NdotV < 0.00001) { // Skip SSR if ray contribution is low
			// TODO
			Reflections.rgb = texelFetch(colortex13, uv, 0).rgb;
			Reflections.a = 1.0;
//		}

		// check if the f0 is within the metal ranges, then tint by albedo if it's true.
//		vec3 Metals = f0  >= 230.0/255.0 ? saturate(albedo + fresnel) : vec3(1.0);

//		Reflections.rgb *= Metals;
//		SunReflection *= Metals;
//		SkyReflection *= Metals;

		// darken albedos, and stop darkening where the sky gets occluded indoors
//		Reflections_Final *= mix(1.0 - (Reflections.a * luma(rayContrib)), 1.0 - luma(rayContrib), Outdoors);
//		Reflections_Final *= 1.0 - luma(rayContrib);

		// apply all reflections to the lighting
		vec3 Reflections_Final = Reflections.rgb;// * luma(rayContrib);
//		Reflections_Final += SkyReflection * luma(rayContrib) * (1.0-Reflections.a);// * Outdoors;

		#ifdef REFLECTION_ROUGH
			dest_color += Reflections_Final;
		#else
			// interpolate between the albedos and reflections using the roughness value instead of the sampling.
			dest_color += Reflections_Final * (1.0 - sqrt(roughness));
		#endif

//		dest_color += SunReflection;
	}

	outColor3 = vec4(clamp(dest_color, 0.000001, 65000.0), 1.0);
}
