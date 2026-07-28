#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"

#define TEX_DEPTH depthtex1


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

layout(r32f) uniform writeonly image2D imgVoxelDepth;
layout(rgba8) uniform writeonly image2D colorimg8;
layout(rgba16) uniform writeonly image2D colorimg9;
layout(rgba8) uniform writeonly image2D colorimg10;

uniform sampler2D TEX_DEPTH;

uniform float viewWidth;
uniform float viewHeight;
uniform int framemod8;
uniform vec2 texelSize;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

#include "/lib/material.glsl"
#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"
#include "/lib/color_transforms.glsl"

#include "/photonics/tracing.glsl"
#include "/photonics/trace_ray.glsl"

ivec2 viewSizeScaled = ivec2(ceil(vec2(viewWidth, viewHeight) * RENDER_SCALE));


void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(uv, viewSizeScaled))) return;

    vec2 tempOffset = vec2(0.0);
    #ifdef TAA_ENABLED
        tempOffset = taa_offsets[framemod8];
    #endif

    #if PHOTONICS_3D_BLOCKS == PH_VOXEL_FULL
        float depth = 1.0;
    #else
        float depth = texelFetch(TEX_DEPTH, uv, 0).r;
    #endif

    vec2 texcoord = (uv + 0.5) * texelSize;

    vec3 screenPos = vec3(texcoord / RENDER_SCALE - vec2(tempOffset) * texelSize * 0.5, depth);
//    vec3 screenPos = vec3(texcoord / RENDER_SCALE, depth);
    vec3 viewPos = toScreenSpace(screenPos);
    vec3 localPos = toWorldSpace(viewPos);

//    vec3 trace_localDir = mat3(gbufferModelViewInverse) * normalize(scene_viewPos);
    vec3 trace_localDir = normalize(localPos - gbufferModelViewInverse[3].xyz);

    RayIterator ray;
    ray.iterations = 100;
//    ray_iter_set_position(ray, rt_camera_position);
    ray_iter_set_position(ray, rt_camera_position + gbufferModelViewInverse[3].xyz);
    ray_iter_set_direction(ray, trace_localDir);
//    ray_iter_offset_position(ray, vec3(0.0));

    RayResult hit;
    if (trace_ray(ray, hit)) {
        vec3 hit_localPos = ray_result_position(hit) - rt_camera_position;
        float hitDist = length(hit_localPos);

        if (hitDist < length(localPos) - 0.04) {
            // update depth
            vec3 hit_viewPos = worldToViewSpace(hit_localPos);
            vec3 hit_screenPos = toClipSpace3(hit_viewPos);
            depth = hit_screenPos.z;

            VoxelData voxel_data = ray_result_voxel_data(hit);

            // update gbuffer color
            vec3 hit_albedo = voxel_data_albedo(voxel_data).rgb;
            hit_albedo = linearToSRGB(hit_albedo);
            imageStore(colorimg8, uv, vec4(hit_albedo, 1.0));

            // update gbuffer normals
            vec3 geometry_normal = ray_result_normal(hit);
            vec3 geoViewNormal = mat3(gbufferModelView) * geometry_normal;
            vec2 encViewNormal = OctEncode(geoViewNormal);
            vec4 packedNormals = vec4(encViewNormal, encViewNormal);
            imageStore(colorimg9, uv, packedNormals);

            // update gbuffer specular
            vec4 hit_specular = voxel_data_specular(voxel_data);
            vec4 specularFinal = hit_specular;
            specularFinal.a = mat_emission(hit_specular);
            imageStore(colorimg10, uv, specularFinal);
        }
    }

    imageStore(imgVoxelDepth, uv, vec4(depth));
}
