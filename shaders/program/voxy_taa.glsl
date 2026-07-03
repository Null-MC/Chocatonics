#include "/lib/common.glsl"
#include "/lib/settings.glsl"


vec2 taaShift() {
    #ifdef TAA_ENABLED
        return taa_offsets[framemod8] * texelSize;
    #else
        return vec2(0.0);
    #endif
}
