#version 430 compatibility

// Accumulate sky gradient

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const ivec3 workGroups = ivec3(16, 16, 1);

layout(rgba16f) uniform image2D imgSkyGradientClouds;

uniform sampler2D noisetex;
uniform sampler2D texSkyGradient;
uniform sampler2DShadow shadowtex0HW;

uniform float far;
uniform vec3 sunVec;
uniform float sunElevation;
uniform vec2 texelSize;
uniform int frameCounter;
uniform float frameTimeCounter;
//uniform float eyeAltitude;
uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform ivec2 eyeBrightnessSmooth;

#include "/lib/sceneBuffer.glsl"

#include "/lib/r2.glsl"
#include "/lib/util.glsl"
#include "/lib/bicubic.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/volumetricClouds.glsl"
#include "/lib/volumetricFog.glsl"


void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (!all(lessThan(uv, ivec2(256)))) return;

    vec2 jitter = R2_samples(frameCounter % 10000);
    vec2 texcoord = saturate((uv + jitter) / 256.0);
    vec3 viewDir = mat3(gbufferModelView) * cartToSphere(texcoord);

    vec4 lightCol = vec4(scene.lightSourceColor, float(sunElevation > 1.e-5) * 2.0 - 1.0);

    float noise = blueNoise(uv, frameCounter);
    vec4 clouds = renderClouds(viewDir * 1024.0, vec3(0.0), noise, scene.sunColorCloud, scene.moonColor, scene.avgSky);
    mat2x3 vL = getVolumetricRays(fract(frameCounter / 1.6180339887), viewDir * 1024.0, lightCol, scene.VFAmount, scene.fogAmount);
    float absorbance = dot(vL[1], vec3(0.22, 0.71, 0.07));

    vec3 sky = texelFetch(texSkyGradient, uv, 0).rgb;
    sky = sky * clouds.a + clouds.rgb;

    // Temporally accumulate sky and light values
    vec3 sky_now = sky * absorbance + vL[0].rgb;
    vec3 sky_last = imageLoad(imgSkyGradientClouds, uv).rgb;
    sky_now = mix(sky_last, sky_now, 0.06);

    imageStore(imgSkyGradientClouds, uv, vec4(clamp(sky_now, 0.0, 65000.0), 1.0));
}
