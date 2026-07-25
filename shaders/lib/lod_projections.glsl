#ifdef LOD_ENABLED
    mat4 GetLodProjection() {
        return mat4(
            gbufferProjection[0][0], 0.0, 0.0, 0.0,
            0.0, gbufferProjection[1][1], 0.0, 0.0,
            0.0, 0.0, 0.0, -1.0,
            0.0, 0.0, near, 0.0);
    }

    mat4 GetLodProjectionPrevious() {
        return mat4(
            gbufferPreviousProjection[0][0], 0.0, 0.0, 0.0,
            0.0, gbufferPreviousProjection[1][1], 0.0, 0.0,
            0.0, 0.0, 0.0, -1.0,
            0.0, 0.0, near, 0.0);
    }

    mat4 GetLodProjectionInverse() {
        return mat4(
            gbufferProjectionInverse[0][0], 0.0, 0.0, 0.0,
            0.0, gbufferProjectionInverse[1][1], 0.0, 0.0,
            0.0, 0.0, 0.0, 1.0/near,
            0.0, 0.0, -1.0, 0.0);
    }

    mat4 gbufferProjection_lod = GetLodProjection();
    mat4 gbufferProjectionInverse_lod = GetLodProjectionInverse();
    mat4 gbufferPreviousProjection_lod = GetLodProjectionPrevious();

    #define IS_DEPTH_SKY (depth <= 0.0)
    #define MAT_PROJ gbufferProjection_lod
    #define MAT_PROJ_INV gbufferProjectionInverse_lod
    #define MAT_PROJ_PREV gbufferPreviousProjection_lod
#else
    #define IS_DEPTH_SKY (depth >= 1.0)
    #define MAT_PROJ gbufferProjection
    #define MAT_PROJ_INV gbufferProjectionInverse
    #define MAT_PROJ_PREV gbufferPreviousProjection
#endif


bool isDepthSky(const in float depth) {
    return IS_DEPTH_SKY;
}

#ifdef LOD_ENABLED
    #define OP_DEPTH_NEARER >

    vec3 screenToNdc(in vec3 screenPos) {
        screenPos.xy = screenPos.xy * 2.0 - 1.0;
        return screenPos;
    }

    vec3 ndcToScreen(in vec3 ndcPos) {
        ndcPos.xy = ndcPos.xy * 0.5 + 0.5;
        return ndcPos;
    }
#else
    #define OP_DEPTH_NEARER <

    vec3 screenToNdc(const in vec3 screenPos) {
        return screenPos * 2.0 - 1.0;
    }

    vec3 ndcToScreen(const in vec3 ndcPos) {
        return ndcPos * 0.5 + 0.5;
    }
#endif

bool isDepthNearer(const in float d1, const in float d2) {
    return d1 OP_DEPTH_NEARER d2;
}

vec3 viewToClipSpace_lod(const in mat4 matProj, const in vec3 viewPos) {
    return ndcToScreen(projMAD(matProj, viewPos) / -viewPos.z);
}

#define toClipSpace3_lod(p) viewToClipSpace_lod(MAT_PROJ, p)

vec3 toScreenSpace_lod(const in vec3 p) {
//	vec4 iProjDiag = vec4(MAT_PROJ_INV[0].x, MAT_PROJ_INV[1].y, MAT_PROJ_INV[2].zw);
//    vec4 fragposition = iProjDiag * screenToNdc(p).xyzz + MAT_PROJ_INV[3];
    vec4 fragposition = MAT_PROJ_INV * vec4(screenToNdc(p), 1.0);
    return fragposition.xyz / fragposition.w;
}

#define toClipSpace3_lodPrev(p) (ndcToScreen(projMAD(MAT_PROJ_PREV, p) / -p.z))
