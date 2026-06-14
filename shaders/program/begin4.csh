#version 430 compatibility

// Accumulate sky gradient

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const ivec3 workGroups = ivec3(16, 16, 1);

layout(rgba16f) uniform image2D imgSkyGradient;

uniform sampler2D noisetex;

uniform vec3 sunVec;
uniform int frameCounter;
uniform float eyeAltitude;
uniform float rainStrength;
uniform mat4 gbufferModelViewInverse;

#include "/lib/sceneBuffer.glsl"

#include "/lib/r2.glsl"
#include "/lib/util.glsl"
#include "/lib/blueNoise.glsl"
#include "/lib/ROBOBO_sky.glsl"


void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (!all(lessThan(uv, ivec2(256)))) return;

    vec2 jitter = R2_samples(frameCounter % 10000);
    vec2 texcoord = saturate((uv + jitter) / 256.0);
    vec3 localViewDir = cartToSphere(texcoord);

    vec3 skyAbsorb = vec3(0.0);
    vec2 planetSphere = vec2(0.0);

    vec3 localSunDir = mat3(gbufferModelViewInverse) * sunVec;
    float noise = blueNoise(uv, frameCounter);

    vec3 sky = calculateAtmosphere(scene.avgSky * 4000.0/2.0, localViewDir, vec3(0.0, 1.0, 0.0), localSunDir, -localSunDir, planetSphere, skyAbsorb, 10, noise);

    sky = mix(sky, vec3(0.02, 0.022, 0.025) * dot(scene.sunColorCloud + scene.moonColorCloud, vec3(0.21, 0.72, 0.07)) * 4000.0, rainStrength * 0.99);

    // Temporally accumulate sky and light values
    vec3 sky_now = sky / 4000.0 * Sky_Brightness;
    vec3 sky_last = imageLoad(imgSkyGradient, uv).rgb;
    sky_now = mix(sky_last, sky_now, 0.06);

    imageStore(imgSkyGradient, uv, vec4(clamp(sky_now, 0.0, 65000.0), 1.0));
}
