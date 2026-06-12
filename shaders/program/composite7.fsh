#version 120
#extension GL_EXT_gpu_shader4 : enable

// Compute 3x3 min max for TAA

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


uniform sampler2D colortex3;


/* RENDERTARGETS: 0,6 */
layout(location = 0) out vec3 outColor0;
layout(location = 1) out vec3 outColor6;

void main() {
    ivec2 center = ivec2(gl_FragCoord.xy);
    vec3 current = texelFetch2D(colortex3, center, 0).rgb;

    vec3 cMin = current;
    vec3 cMax = current;

    current = texelFetch2D(colortex3, center + ivec2(-1, -1), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    current = texelFetch2D(colortex3, center + ivec2(-1, 0), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    current = texelFetch2D(colortex3, center + ivec2(-1, 1), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    current = texelFetch2D(colortex3, center + ivec2(0, -1), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    current = texelFetch2D(colortex3, center + ivec2(0, 1), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    current = texelFetch2D(colortex3, center + ivec2(1, -1), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    current = texelFetch2D(colortex3, center + ivec2(1, 0), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    current = texelFetch2D(colortex3, center + ivec2(1, 1), 0).rgb;
    cMin = min(cMin, current);
    cMax = max(cMax, current);

    outColor0 = cMax;
    outColor6 = cMin;
}
