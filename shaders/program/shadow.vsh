#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in vec4 mc_Entity;
in vec4 at_midBlock;
in vec4 mc_midTexCoord;

out VertexData {
    vec2 texcoord;
} vOut;

#ifdef VOXEL_ENABLED
    layout(r16ui) uniform writeonly uimage3D imgVoxels;
#endif

uniform usampler2D texBlockMeta;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform vec3 sunVec;
uniform float aspectRatio;
uniform float sunElevation;
uniform float lightSign;
uniform float cosFov;
uniform vec3 shadowViewDir;
uniform vec3 shadowCamera;
uniform vec3 shadowLightVec;
uniform float shadowMaxProj;
uniform int renderStage;

#include "/lib/blocks.glsl"
#include "/lib/blockMeta.glsl"
#include "/lib/Shadow_Params.glsl"
#include "/lib/windWaving.glsl"

#ifdef VOXEL_ENABLED
    #include "/lib/voxel.glsl"
#endif


#ifdef SHADOW_FRUSTRUM_CULLING
    bool intersectCone(float coneHalfAngle, vec3 coneTip , vec3 coneAxis, vec3 rayOrig, vec3 rayDir, float maxZ) {
        vec3 co = rayOrig - coneTip;
        float prod = dot(normalize(co), coneAxis);
        if (prod <= -coneHalfAngle) {
            // In view frustrum
            return true;
        }

        float coneHalfAngle2 = coneHalfAngle*coneHalfAngle;
        float ray_dot_axis = dot(rayDir, coneAxis);
        float co_dot_axis = dot(co, coneAxis);

        float a = ray_dot_axis*ray_dot_axis - coneHalfAngle2;
        float b = 2.0 * (ray_dot_axis * co_dot_axis - dot(rayDir, co) * coneHalfAngle2);
        float c = co_dot_axis*co_dot_axis - dot(co, co) * coneHalfAngle2;

        float det = b*b - 4.0*a*c;
        if (det < 0.0) {
            // No intersection with either forward cone and backward cone
            return false;
        }

        det = sqrt(det);
        float t2 = (-b + det) / (2.0 * a);
        if (t2 <= 0.0 || t2 >= maxZ) {
            // Idk why it works
            return false;
        }

        return true;
    }
#endif

vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), 1.0);
}


void main() {
    int blockId = int(mc_Entity.x);

    bool isRenderTerrain = renderStage == MC_RENDER_STAGE_TERRAIN_SOLID
        || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT
        || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
        || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT;

//    if (blockId == BLOCK_WATER || blockId == 9) gl_Position.w = -1.0;
    if (blockId == BLOCK_WATER) {
        gl_Position.w = -1.0;
        return;
    }

    vOut.texcoord = gl_MultiTexCoord0.xy;

    vec3 viewPos = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
    vec3 localPos = mul3(shadowModelViewInverse, viewPos);

    #ifdef VOXEL_ENABLED
        uint voxelId = uint(blockId);
        if (blockId < 0) voxelId = BLOCK_SOLID;

        vec3 originPos = vec3(-9999.0);

//        bool isRenderTerrain = renderStage == MC_RENDER_STAGE_TERRAIN_SOLID
//            || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT
//            || renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED
//            || renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT;

        if (isRenderTerrain) {
            bool ignoreBlock = blockId == BLOCK_WATER || blockId == BLOCK_IGNORED
                    || blockId == BLOCK_VINE || blockId == BLOCK_SSS_HIGH
                    || blockId == BLOCK_GLASS;

            if (!ignoreBlock && (gl_VertexID % 4) == 0) {
                originPos = localPos + at_midBlock.xyz / 64.0;
            }
        }

        ivec3 voxelPos = ivec3(GetVoxelPosition(originPos));
        if (IsInVoxelBounds(voxelPos) && voxelId > 0u) {
            imageStore(imgVoxels, voxelPos, uvec4(voxelId));
        }
    #endif

    #if PHOTONICS_3D_BLOCKS == PH_VOXEL_FULL || defined(PHOTONICS_SHADOWS)
        if (isRenderTerrain) {
            gl_Position = vec4(0.0, 0.0, 1e30, 0.0); // Degenerates the triangle
            return;
        }
    #elif PHOTONICS_3D_BLOCKS == PH_VOXEL_HYBRID
        // TODO
        if (blockId == BLOCK_PLANT_WAVING_TOP || blockId == BLOCK_LEAVES) {
            gl_Position = vec4(0.0, 0.0, 1e30, 0.0); // Degenerates the triangle
            return;
        }
    #endif

    // Check if the vertice is going to cast shadows
    #ifdef SHADOW_FRUSTRUM_CULLING
        if (!intersectCone(cosFov, shadowCamera, shadowViewDir, viewPos, -shadowLightVec, shadowMaxProj)) {
            gl_Position = vec4(0.0, 0.0, 1e30, 0.0); // Degenerates the triangle
            return;
        }
    #endif

    #ifdef WAVY_PLANTS
        bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;
//        vec3 localPos = mul3(shadowModelViewInverse, viewPos);

        uint blockMeta = SampleBlockMeta(blockId);

//        if (blockId == BLOCK_PLANT_WAVING_TOP && istopv && length(viewPos.xy) < 24.0) {
        if (hasBit(blockMeta, BIT_WAVING_TOP) && istopv && length(viewPos.xy) < 24.0) {
            localPos += calcMovePlants(localPos + cameraPosition) / 255.0 * gl_MultiTexCoord1.y;
        }

//        if (blockId == BLOCK_PLANT_WAVING_FULL && length(viewPos.xy) < 24.0) {
        if (hasBit(blockMeta, BIT_WAVING_FULL) && length(viewPos.xy) < 24.0) {
            localPos += calcMoveLeaves(localPos + cameraPosition, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5)) / 255.0 * gl_MultiTexCoord1.y;
        }

//        viewPos = mul3(shadowModelView, localPos);
    #endif

    viewPos = mul3(shadowModelView, localPos);

    gl_Position = BiasShadowProjection(toClipSpace3(viewPos));
    gl_Position.z /= 6.0;
}
