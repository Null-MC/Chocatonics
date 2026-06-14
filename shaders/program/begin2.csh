#version 430 compatibility

// Forward lightmap

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

layout(rgba16f) uniform image2D imgLightMap_forward;

#include "/lib/sceneBuffer.glsl"


const float[17] Slightmap = float[17](
    14.0, 17.0, 19.0, 22.0, 24.0, 28.0, 31.0, 40.0, 60.0, 79.0, 93.0, 110.0, 132.0, 160.0, 197.0, 249.0, 249.0);


void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
//    if (!all(lessThan(uv, ivec2(16)))) return;

    float minLight = MIN_LIGHT_AMOUNT / (scene.exposure + scene.rodExposure / (scene.rodExposure) * scene.exposure);

    // Lightmap for forward shading (contains average integrated sky color across all faces + torch + min ambient)
    vec3 avgAmbient = (scene.ambientUp + scene.ambientLeft + scene.ambientRight + scene.ambientDown + scene.ambientB + scene.ambientF) / 6.0;

    float torchLut = clamp(15.5 - uv.x, 0.5, 15.5);
    torchLut = torchLut + 0.712;

    float torch_lightmap = max(1.0/(torchLut*torchLut) - 1.0/(16.212*16.212), 0.0);
    torch_lightmap = torch_lightmap * TORCH_AMOUNT * 10.0;

    float sky_lightmap = (Slightmap[uv.y] - 14.0) / 235.0;
    vec3 ambient = avgAmbient * sky_lightmap + torch_lightmap * TorchColor * TORCH_AMOUNT + minLight;

    // Temporally accumulate
    vec3 color_now = ambient * Ambient_Mult;
    vec3 color_last = imageLoad(imgLightMap_forward, uv).rgb;
    color_now = mix(color_last, color_now, 0.06);

    imageStore(imgLightMap_forward, uv, vec4(color_now, 1.0));
}
