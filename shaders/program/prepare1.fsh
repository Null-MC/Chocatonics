#version 430 compatibility

// Prepares sky textures (2 * 256 * 256), computes light values and custom lightmaps

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define TEX_SKY_LUT colortex4


in VertexData {
    flat vec3 ambientUp;
    flat vec3 ambientLeft;
    flat vec3 ambientRight;
    flat vec3 ambientB;
    flat vec3 ambientF;
    flat vec3 ambientDown;
//    flat vec3 zenithColor;
    flat vec3 sunColor;
    flat vec3 sunColorCloud;
    flat vec3 moonColor;
    flat vec3 moonColorCloud;
    flat vec3 lightSourceColor;
    flat vec3 avgSky;
    flat vec2 tempOffsets;
    flat float exposure;
//    flat float exposureF;
    flat float avgBrightness;
    flat float rodExposure;
    flat float fogAmount;
    flat float VFAmount;
    flat float avgL2;
//    flat float centerDepth;
} vIn;

uniform sampler2D colortex4;
uniform sampler2D noisetex;
uniform sampler2D texBlueNoise;
uniform sampler2DShadow shadowtex0HW;

uniform float far;
uniform float near;
uniform int frameCounter;
uniform float rainStrength;
uniform float eyeAltitude;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float sunElevation;
uniform vec3 cameraPosition;
uniform ivec2 eyeBrightnessSmooth;

vec4 lightCol = vec4(vIn.lightSourceColor, float(sunElevation > 1.e-5) * 2.0 - 1.0);

#include "/lib/util.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/projections.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/ROBOBO_sky.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/volumetricClouds.glsl"
#include "/lib/volumetricFog.glsl"


const float[17] Slightmap = float[17](14.0,17.,19.0,22.0,24.0,28.0,31.0,40.0,60.0,79.0,93.0,110.0,132.0,160.0,197.0,249.0,249.0);


/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outColor4;

void main() {
    outColor4 = vec4(0.0);

    float minLight = MIN_LIGHT_AMOUNT * 0.007 / (vIn.exposure + vIn.rodExposure / (vIn.rodExposure) * vIn.exposure);

    // Lightmap for forward shading (contains average integrated sky color across all faces + torch + min ambient)
    vec3 avgAmbient = (vIn.ambientUp + vIn.ambientLeft + vIn.ambientRight + vIn.ambientB + vIn.ambientF + vIn.ambientDown) / 6.0;

    if (gl_FragCoord.x < 17.0 && gl_FragCoord.y < 17.0) {
        float torchLut = clamp(16.0 - gl_FragCoord.x, 0.5, 15.5);
        torchLut = torchLut + 0.712;

        float torch_lightmap = max(1.0/torchLut/torchLut - 1.0/16.212/16.212, 0.0);
        torch_lightmap = torch_lightmap * TORCH_AMOUNT * 10.0;

        float sky_lightmap = (Slightmap[int(gl_FragCoord.y)] - 14.0) / 235.0;
        vec3 ambient = avgAmbient * sky_lightmap + torch_lightmap * TorchColor * TORCH_AMOUNT + minLight;

        outColor4 = vec4(ambient * Ambient_Mult, 1.0);
    }

    // Lightmap for deferred shading (contains only torch + min ambient)
    if (gl_FragCoord.x < 17.0 && gl_FragCoord.y > 19.0 && gl_FragCoord.y < 19.0 + 17.0){
        float torchLut = clamp(16.0 - gl_FragCoord.x, 0.5, 15.5);
        torchLut = torchLut + 0.712;

        float torch_lightmap = max(1.0/torchLut/torchLut - 1.0/16.212/16.212, 0.0);

        float ambient = torch_lightmap * TORCH_AMOUNT * 10.0;

        float sky_lightmap = (Slightmap[int(gl_FragCoord.y-19.0)]-14.0)/235.0/150.0;

        outColor4 = vec4(sky_lightmap, ambient, minLight, 1.0) * Ambient_Mult;
    }

    // Save light values
    if (gl_FragCoord.x < 1. && gl_FragCoord.y > 19.0+18.0 && gl_FragCoord.y < 19.0+18.0+1.0)
        outColor4 = vec4(vIn.ambientUp, 1.0);

    if (gl_FragCoord.x > 1. && gl_FragCoord.x < 2.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.ambientDown, 1.0);

    if (gl_FragCoord.x > 2. && gl_FragCoord.x < 3.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.ambientLeft, 1.0);

    if (gl_FragCoord.x > 3. && gl_FragCoord.x < 4.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.ambientRight, 1.0);

    if (gl_FragCoord.x > 4. && gl_FragCoord.x < 5.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.ambientB, 1.0);

    if (gl_FragCoord.x > 5. && gl_FragCoord.x < 6.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.ambientF, 1.0);

    if (gl_FragCoord.x > 6. && gl_FragCoord.x < 7.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.lightSourceColor, 1.0);

    if (gl_FragCoord.x > 7. && gl_FragCoord.x < 8.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(avgAmbient, 1.0);

    if (gl_FragCoord.x > 8. && gl_FragCoord.x < 9.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.sunColor, 1.0);

    if (gl_FragCoord.x > 9. && gl_FragCoord.x < 10.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.moonColor, 1.0);

    if (gl_FragCoord.x > 11. && gl_FragCoord.x < 12.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.avgSky, 1.0);

    if (gl_FragCoord.x > 12. && gl_FragCoord.x < 13.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.sunColorCloud, 1.0);

    if (gl_FragCoord.x > 13. && gl_FragCoord.x < 14.  && gl_FragCoord.y > 19.+18. && gl_FragCoord.y < 19.+18.+1 )
        outColor4 = vec4(vIn.moonColorCloud, 1.0);

    // Sky gradient (no clouds)
    if (gl_FragCoord.x > 18.0 && gl_FragCoord.y > 1.0 && gl_FragCoord.x < 18.0+257.0) {
        #ifdef WORLD_NETHER
            outColor4 = vec4(100.0, 40.0, 12.0, 1.0);
        #else
            vec2 p = saturate(floor(gl_FragCoord.xy - vec2(18.0, 1.0)) / 256.0 + vIn.tempOffsets / 256.0);
            vec3 viewVector = cartToSphere(p);

            vec2 planetSphere = vec2(0.0);
            vec3 sky = vec3(0.0);
            vec3 skyAbsorb = vec3(0.0);
            vec3 WsunVec = mat3(gbufferModelViewInverse) * sunVec;

            sky = calculateAtmosphere(vIn.avgSky * 4000.0/2.0, viewVector, vec3(0.0, 1.0, 0.0), WsunVec, -WsunVec, planetSphere, skyAbsorb, 10, blueNoise(gl_FragCoord.xy, frameCounter));

            sky = mix(sky, vec3(0.02, 0.022, 0.025) * dot(vIn.sunColorCloud + vIn.moonColorCloud, vec3(0.21, 0.72, 0.07)) * 4000.0, rainStrength * 0.99);

            //	transmittance *= exp(-(rainCoef)*rainDensity*L);
            outColor4 = vec4(sky / 4000.0 * Sky_Brightness, 1.0);
        #endif
    }

    #ifndef WORLD_NETHER
        // Sky gradient with clouds
        if (gl_FragCoord.x > 18.0+257.0 && gl_FragCoord.y > 1.0 && gl_FragCoord.x < 18.0+257.0+257.0) {
            vec2 p = saturate(floor(gl_FragCoord.xy - vec2(18.0+257.0, 1.0))/256.0 + vIn.tempOffsets/256.0);
            vec3 viewVector = mat3(gbufferModelView) * cartToSphere(p);
            vec4 clouds = renderClouds(viewVector * 1024.0, vec3(0.0), blueNoise(gl_FragCoord.xy, frameCounter), vIn.sunColorCloud, vIn.moonColor, vIn.avgSky);
            mat2x3 vL = getVolumetricRays(fract(frameCounter / 1.6180339887), viewVector * 1024.0, lightCol);
            float absorbance = dot(vL[1], vec3(0.22, 0.71, 0.07));

            vec3 skytex = texelFetch(colortex4, ivec2(gl_FragCoord.xy) - ivec2(257, 0), 0).rgb / 150.0;
            skytex = skytex * clouds.a + clouds.rgb;

            outColor4 = vec4(skytex * absorbance + vL[0].rgb, 1.0);
        }
    #endif

    // Temporally accumulate sky and light values
    vec3 temp = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0).rgb;
    vec3 curr = outColor4.rgb * 150.0;

    outColor4.rgb = clamp(mix(temp, curr, 0.06), 0.0, 65000.0);

    // Exposure values
    if (gl_FragCoord.x > 10.0 && gl_FragCoord.x < 11.0 && gl_FragCoord.y > 19.0 + 18.0 && gl_FragCoord.y < 19.0 + 18.0 + 1.0)
        outColor4 = vec4(vIn.exposure, vIn.avgBrightness, vIn.avgL2, 1.0);

    if (gl_FragCoord.x > 14.0 && gl_FragCoord.x < 15.0 && gl_FragCoord.y > 19.0 + 18.0 && gl_FragCoord.y < 19.0 + 18.0 + 1.0)
        outColor4 = vec4(vIn.rodExposure, temp.g, 0.0, 1.0);
}
