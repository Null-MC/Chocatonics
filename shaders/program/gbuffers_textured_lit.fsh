#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;
} vIn;

uniform sampler2D gtexture;
uniform sampler2D texLightMap_forward;
uniform sampler2DShadow shadowtex0HW;

uniform vec3 sunVec;
uniform vec3 upVec;
uniform float lightSign;
uniform vec2 texelSize;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform float sunElevation;
uniform float rainStrength;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float alphaTestRef;
//uniform float frameTimeCounter;
//uniform int frameCounter;
uniform int framemod8;

#include "/lib/sceneBuffer.glsl"

#include "/lib/ign.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/projections.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/shadowSamplingBicubic.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture(gtexture, vIn.lmtexcoord.xy) * vIn.color;

	if (outColor2.a < alphaTestRef) discard;

	vec2 taa_offset = taa_offsets[framemod8];

	float avgBlockLum = luma(textureLod(gtexture, vIn.lmtexcoord.xy, 128).rgb * vIn.color.rgb);
	outColor2.rgb = saturate(outColor2.rgb * pow(avgBlockLum, -0.33) * 0.85);
	vec3 albedo = toLinear(outColor2.rgb);

	vec3 normal = vIn.normalMat.xyz;
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz * vec3(texelSize/RENDER_SCALE, 1.0) - vec3(vec2(taa_offset)*texelSize*0.5, 0.0));

	float NdotL = -lightSign*dot(normal, sunVec);
	float NdotU = dot(upVec,normal);
	float diffuseSun = 0.712;

	vec3 direct = scene.lightSourceColor / PI;

	// compute shadows only if not backface
	if (diffuseSun > 0.001) {
		vec3 p3 = mul3(gbufferModelViewInverse, fragpos);
		vec3 projectedShadowPosition = mul3(shadowModelView, p3);
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		// apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;

		// do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){
			const float threshMul = sqrt(2048.0 / shadowMapResolution*shadowDistance/128.0);
			float distortThresh = 1.0 / (distortFactor * distortFactor);
			float diffthresh = 0.0002;

			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

			float noise = IGN(taa_offset.x * 0.5 + 0.5);

			vec2 offsetS = vec2(
				cos(noise * PI*2.0),
				sin(noise * PI*2.0));

			float shading = shadow2D_bicubic(shadowtex0HW, vec3(projectedShadowPosition + vec3(0.0, 0.0, diffthresh * -1.2)));

			direct *= shading;
		}
	}

	direct *= diffuseSun;

	vec2 lmcoord = (vIn.lmtexcoord.zw * 15.0 + 0.5) / 16.0;
	vec3 ambient = texture(texLightMap_forward, lmcoord).rgb;

	vec3 diffuseLight = direct * vIn.lmtexcoord.w + ambient;

	outColor2.rgb = diffuseLight * albedo * 8.0/3.0 * 0.1;
}
