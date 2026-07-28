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


#ifdef PHOTONICS_3D_BLOCKS
    layout(r32f) uniform image2D imgVoxelDepth;
    layout(rgba8) uniform image2D colorimg8;
    layout(rgba16) uniform image2D colorimg9;
    layout(rgba8) uniform image2D colorimg10;
#endif

uniform sampler2D TEX_DEPTH;
uniform sampler2D TEX_GB_NORMAL;
uniform sampler2D TEX_GB_WORLD;

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

#include "/lib/octohedral.glsl"
#include "/lib/projections.glsl"
#include "/lib/color_transforms.glsl"

#ifdef PHOTONICS_3D_BLOCKS
    #include "/lib/material.glsl"
    #include "/photonics/tracing.glsl"
    #include "/photonics/trace_ray.glsl"
#endif


vec3 load_player_position() {
    ivec2 uv = ivec2(gl_FragCoord.xy);

    #ifdef PHOTONICS_3D_BLOCKS
        float depth = imageLoad(imgVoxelDepth, uv).r;
    #else
        float depth = texelFetch(TEX_DEPTH, uv, 0).r;
    #endif

    vec2 tempOffset = vec2(0.0);
    #ifdef TAA_ENABLED
        //tempOffset = -taa_offsets[framemod8];
    #endif

    vec2 texcoord = gl_FragCoord.xy * texelSize;
    vec3 screenPos = vec3(texcoord / RENDER_SCALE - vec2(tempOffset) * texelSize * 0.5, depth);
    vec3 viewPos = toScreenSpace(screenPos);
    vec3 localPos = toWorldSpace(viewPos);

    return localPos;
}

void load_fragment_data(out vec3 geometry_normal, out vec3 texture_normal) {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    vec4 normalData = texelFetch(TEX_GB_NORMAL, uv, 0);

    geometry_normal = mat3(gbufferModelViewInverse) * OctDecode(normalData.xy);
    texture_normal  = mat3(gbufferModelViewInverse) * OctDecode(normalData.zw);

    // TODO: manual 3D block trace
    #ifdef PHOTONICS_3D_BLOCKS
        vec2 tempOffset = vec2(0.0);
        #ifdef TAA_ENABLED
            tempOffset = taa_offsets[framemod8];
        #endif

        float depth = texelFetch(TEX_DEPTH, uv, 0).r;
        vec2 texcoord = gl_FragCoord.xy * texelSize;
        vec3 scene_screenPos = vec3(texcoord / RENDER_SCALE - vec2(tempOffset) * texelSize * 0.5, depth);
//        vec3 scene_screenPos = vec3(texcoord / RENDER_SCALE, depth);
        vec3 scene_viewPos = toScreenSpace(scene_screenPos);
        vec3 scene_localPos = toWorldSpace(scene_viewPos);

//        vec3 trace_localDir = mat3(gbufferModelViewInverse) * normalize(scene_viewPos);
        vec3 trace_localDir = normalize(scene_localPos - gbufferModelViewInverse[3].xyz);

        RayIterator ray;
        ray.iterations = 100;
        ray_iter_set_position(ray, rt_camera_position + gbufferModelViewInverse[3].xyz);
        ray_iter_set_direction(ray, trace_localDir);

        RayResult hit;
        if (trace_ray(ray, hit)) {
            vec3 hit_position = ray_result_position(hit);
            vec3 hit_localPos = hit_position - rt_camera_position;
            float hitDist = length(hit_localPos);

            if (hitDist < length(scene_localPos) - 0.04) {
                scene_localPos = hit_localPos;
                geometry_normal = ray_result_normal(hit);
                texture_normal = geometry_normal;

                // update depth
                scene_viewPos = worldToViewSpace(scene_localPos);
                scene_screenPos = toClipSpace3(scene_viewPos);
                depth = scene_screenPos.z;

                // update gbuffer normals
                vec3 geoViewNormal = mat3(gbufferModelView) * geometry_normal;
                vec3 texViewNormal = mat3(gbufferModelView) * texture_normal;
                vec4 packedNormals = vec4(OctEncode(geoViewNormal), OctEncode(texViewNormal));
                imageStore(colorimg9, uv, packedNormals);

                VoxelData voxel_data = ray_result_voxel_data(hit);

                // update gbuffer color
                vec3 hit_albedo = voxel_data_albedo(voxel_data).rgb;
                hit_albedo = linearToSRGB(hit_albedo);
                imageStore(colorimg8, uv, vec4(hit_albedo, 1.0));

                // update gbuffer specular
                vec4 hit_specular = voxel_data_specular(voxel_data);
                vec4 specularFinal = hit_specular;
                specularFinal.a = mat_emission(hit_specular);
                imageStore(colorimg10, uv, specularFinal);
            }
        }

        imageStore(imgVoxelDepth, uv, vec4(depth));
    #endif
}

bool is_in_world() {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(TEX_DEPTH, uv, 0).r;
    return depth < 1.0;
}

bool is_hand_at() {
    ivec2 uv = ivec2(gl_FragCoord.xy);
    float mat = texelFetch(TEX_GB_WORLD, uv, 0).w;
    return abs(mat - 0.75) < 0.01;
}

vec2 get_taa_jitter() {
    #ifdef TAA_ENABLED
        return 2.0 * taa_offsets[framemod8] * texelSize;
    #else
        return vec2(0.0);
    #endif
}
