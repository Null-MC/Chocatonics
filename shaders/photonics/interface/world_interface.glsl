#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define TEX_DEPTH depthtex0

#ifdef NETHER
    #define WORLD_NETHER
#elif defined(END)
    #define WORLD_END
#else
    #define WORLD_OVERWORLD
#endif

//#ifndef OVERWORLD
//    #undef SHADOWS_ENABLED
//    #undef SHADOW_CLOUDS
//#endif

uniform sampler2D TEX_DEPTH;
uniform sampler2D colortex1;

uniform float near;
uniform float far;
uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
uniform int framemod8;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#include "/lib/decode.glsl"
#include "/lib/projections.glsl"


vec3 load_player_position() {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(TEX_DEPTH, uv, 0).r;

    vec2 tempOffset = vec2(0.0);
    #ifdef TAA
        //tempOffset = -taa_offsets[framemod8];
    #endif

    vec2 texcoord = gl_FragCoord.xy * texelSize;
    vec3 screenPos = vec3(texcoord / RENDER_SCALE - vec2(tempOffset) * texelSize * 0.5, depth);
    vec3 viewPos = toScreenSpace(screenPos);
    return toWorldSpace(viewPos);
}

void load_fragment_data(out vec3 geometry_normal, out vec3 texture_normal) {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    vec4 data = texelFetch(colortex1, uv, 0);
    vec4 dataUnpacked0 = vec4(decodeVec2(data.x), decodeVec2(data.y));
     vec4 dataUnpacked1 = vec4(decodeVec2(data.z), decodeVec2(data.w));
    geometry_normal = mat3(gbufferModelViewInverse) * decode(dataUnpacked0.yw);

    // TODO
    texture_normal = geometry_normal;
//    texture_normal = mat3(gbufferModelViewInverse) * decode(dataUnpacked1.yw);
}

bool is_in_world() {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(TEX_DEPTH, uv, 0).r;
    return depth < 1.0;
}

bool is_hand_at() {
    return false;
}

vec2 get_taa_jitter() {
    #ifdef TAA
        return 2.0 * taa_offsets[framemod8] * texelSize;
    #else
        return vec2(0.0);
    #endif
}
