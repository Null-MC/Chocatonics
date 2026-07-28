#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#ifdef DISTANT_HORIZONS
    // This SHOULD be dhDepthTex1, but that is a frame behind here
    #define TEX_DEPTH_LOD dhDepthTex0
    #define MAT_LOD_PROJ_INV dhProjectionInverse
#elif defined(VOXY)
    #define TEX_DEPTH_LOD vxDepthTexOpaque
    #define MAT_LOD_PROJ_INV vxProjInv
#endif


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

#if TAA_RENDER_SCALE == 100
    const vec2 workGroupsRender = vec2(1.0, 1.0);
#elif TAA_RENDER_SCALE == 90
    const vec2 workGroupsRender = vec2(0.9, 0.9);
#elif TAA_RENDER_SCALE == 80
    const vec2 workGroupsRender = vec2(0.8, 0.8);
#elif TAA_RENDER_SCALE == 70
    const vec2 workGroupsRender = vec2(0.7, 0.7);
#elif TAA_RENDER_SCALE == 60
    const vec2 workGroupsRender = vec2(0.6, 0.6);
#elif TAA_RENDER_SCALE == 50
    const vec2 workGroupsRender = vec2(0.5, 0.5);
#endif

layout(r32f) uniform writeonly image2D imgVoxyDepthOpaque;

uniform sampler2D depthtex1;
uniform sampler2D TEX_DEPTH_LOD;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 MAT_LOD_PROJ_INV;

#include "/lib/projections.glsl"


ivec2 viewSizeScaled = ivec2(ceil(vec2(viewWidth, viewHeight) * RENDER_SCALE));


float getMergedDepth(const in ivec2 uv, sampler2D depthtex, sampler2D lodDepthTex) {
    float depth = texelFetch(depthtex, uv, 0).r;

    bool isSky = false;
    bool isLod = false;
    if (isLod = (depth >= 1.0)) {
        depth = texelFetch(lodDepthTex, uv, 0).r;

        if (depth >= 1.0) isSky = true;
    }

    if (isSky) return 0.0;

    vec3 screenPos = vec3((uv + 0.5) / viewSizeScaled, depth);
    float viewPosZ = screenToViewSpace(isLod ? MAT_LOD_PROJ_INV : gbufferProjectionInverse, screenPos).z;
    return -near / viewPosZ;
}


void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(uv, viewSizeScaled))) return;

    float depth_opaque = getMergedDepth(uv, depthtex1, TEX_DEPTH_LOD);
    imageStore(imgVoxyDepthOpaque, uv, vec4(depth_opaque));
}
