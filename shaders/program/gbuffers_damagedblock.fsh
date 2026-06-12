#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

uniform sampler2D texture;
uniform sampler2DShadow shadowtex0HW;
uniform sampler2D gaux1;

uniform vec4 lightCol;
uniform vec3 sunVec;
uniform vec3 upVec;
uniform vec2 texelSize;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform float sunElevation;
uniform float rainStrength;
uniform vec3 cameraPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float frameTimeCounter;
//uniform int frameCounter;
uniform int framemod8;

#include "/lib/ign.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/projections.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/shadowSampling.glsl"
#include "/lib/shadowSamplingBicubic.glsl"


/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor2;

void main() {
	outColor2 = texture2D(texture, lmtexcoord.xy) * color;
	vec2 tempOffset = taa_offsets[framemod8];

	if (outColor2.a > 0.1) {
		vec3 albedo = toLinear(outColor2.rgb);

		vec3 normal = normalMat.xyz;
		vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));

		float NdotL = lightCol.a * dot(normal, sunVec);
		float NdotU = dot(upVec, normal);
		float diffuseSun = saturate(NdotL);
		vec3 direct = texelFetch2D(gaux1, ivec2(6, 37), 0).rgb / PI;

		//compute shadows only if not backface
		if (diffuseSun > 0.001) {
			vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
			vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

			//apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;

			//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){
				const float threshMul = sqrt(2048.0/shadowMapResolution*shadowDistance/128.0);
				float distortThresh = 1.0/(distortFactor*distortFactor);
				float diffthresh = facos(diffuseSun)*distortThresh/800*threshMul;

				projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

				float noise = IGN(tempOffset.x * 0.5 + 0.5);

				vec2 offsetS = vec2(cos(noise * PI*2.0), sin(noise * PI*2.0));

				float shading = shadow2D_bicubic(shadowtex0HW, vec3(projectedShadowPosition + vec3(0.0, 0.0, -diffthresh * 1.2)));

				direct *= shading;
			}
		}

		direct *= diffuseSun;

		vec3 ambient = texture2D(gaux1, (lmtexcoord.zw * 15.0 + 0.5) * texelSize).rgb;

		vec3 diffuseLight = direct + ambient;

		outColor2.rgb = diffuseLight * albedo * 8.0 / 1500.0 * 0.1;
	}
}
