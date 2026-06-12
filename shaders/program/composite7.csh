#version 430 compatibility

// Compute 3x3 min max for TAA

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(RENDER_SCALE_X, RENDER_SCALE_Y);

shared vec3 sharedBuffer[18*18];

layout(rgba16f) uniform writeonly image2D imgTAA_min;
layout(rgba16f) uniform writeonly image2D imgTAA_max;

uniform sampler2D colortex3;

uniform float viewWidth;
uniform float viewHeight;


vec2 viewSizeScaled = vec2(viewWidth, viewHeight) * RENDER_SCALE;

int getSharedIndex(const in ivec2 uv) {
    return uv.y * 18 + uv.x;
}

void copyToShared(const in ivec2 uv_base, const in uint i_shared) {
    if (i_shared >= (18*18)) return;

    ivec2 uv = uv_base + ivec2(i_shared % 18, i_shared / 18);
    sharedBuffer[i_shared] = texelFetch(colortex3, uv, 0).rgb;
}

void sampleMinMax(inout vec3 cMin, inout vec3 cMax, const in ivec2 uv) {
    vec3 color = sharedBuffer[getSharedIndex(uv)];

    cMin = min(cMin, color);
    cMax = max(cMax, color);
}


void main() {
    // preload shared memory
    uint i_base = gl_LocalInvocationIndex * 2u;
    ivec2 uv_base = ivec2(gl_WorkGroupID.xy * gl_WorkGroupSize.xy) - 1;

    copyToShared(uv_base, i_base + 0);
    copyToShared(uv_base, i_base + 1);

    memoryBarrierShared();
    barrier();

    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(uv, viewSizeScaled))) return;

    ivec2 local_uv = ivec2(gl_LocalInvocationID.xy) + 1;

    vec3 current = sharedBuffer[getSharedIndex(local_uv)];
    vec3 cMin = current;
    vec3 cMax = current;

    sampleMinMax(cMin, cMax, local_uv + ivec2(-1, -1));
    sampleMinMax(cMin, cMax, local_uv + ivec2(-1,  0));
    sampleMinMax(cMin, cMax, local_uv + ivec2(-1,  1));
    sampleMinMax(cMin, cMax, local_uv + ivec2( 0, -1));
    sampleMinMax(cMin, cMax, local_uv + ivec2( 0,  1));
    sampleMinMax(cMin, cMax, local_uv + ivec2( 1, -1));
    sampleMinMax(cMin, cMax, local_uv + ivec2( 1,  0));
    sampleMinMax(cMin, cMax, local_uv + ivec2( 1,  1));

    imageStore(imgTAA_min, uv, vec4(cMin, 1.0));
    imageStore(imgTAA_max, uv, vec4(cMax, 1.0));
}
