#define PH_MAX_GI_ITERATIONS 100

uniform vec3 shadowLightPosition;

#include "/photonics/interface/lighting_interface.glsl"
#include "/photonics/tracing.glsl"
#include "/photonics/utility/random.glsl"

#include "/photonics/modifiers/indirect_surface_sample_modifier.glsl"
#include "/photonics/trace_ray.glsl"


void sample_indirect(inout vec3 indirect_color, vec3 sample_rt_pos, vec3 geo_normal, vec3 tex_normal, inout uint rnd_state,
    out vec3 first_hit, out vec3 first_normal) {

    vec3 trace_localDir = ph_rand_direction(rnd_state, tex_normal);
//    lightEmittance = vec3(0.0); // TODO: dont think this is set anymore

    RayIterator ray;
    ray.iterations = PH_MAX_GI_ITERATIONS;
    ray_iter_set_position(ray, sample_rt_pos);
    ray_iter_set_direction(ray, trace_localDir);
    ray_iter_offset_position(ray, 0.1 * geo_normal);

    RayResult hit;
    vec3 tint = vec3(1.0);

    #ifdef SHADOW_COLORED
        bool is_hit = trace_ray(ray, hit, tint);
    #else
        bool is_hit = trace_ray(ray, hit);
    #endif

    vec3 final_color = vec3(0.0);

    if (!is_hit) {
        #ifdef PH_ENABLE_GI
            // hit sky
            vec3 playerPos = sample_rt_pos - rt_camera_position;
            final_color = get_sky_color(playerPos, trace_localDir);
        #endif

        first_hit = vec3(-1.0);
    }
    else {
        VoxelData voxel_data = ray_result_voxel_data(hit);
        vec3 hit_albedo = voxel_data_albedo(voxel_data).rgb;
        hit_albedo = toLinear(hit_albedo);

        vec3 hit_position = ray_result_position(hit);
        vec3 hit_localPos = hit_position - rt_camera_position;
        vec3 hit_localNormal = ray_result_normal(hit);

        first_hit = hit_position;
        first_normal = hit_localNormal;

        // TODO
        vec3 hit_emission = vec3(0.0); //8.0 * lightEmittance;
        vec3 sample_color = vec3(0.0);

        #ifdef PH_ENABLE_GI
            vec3 localSkyLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

            float hit_skyLightF = ray_result_skylight(hit) / 15.0;
            hit_skyLightF = saturate(hit_skyLightF);

            // trace sun
            ray_iter_set_direction(ray, localSkyLightDir);
            ray_iter_offset_position(ray, 0.1 * hit_localNormal);

            RayResult hit2;
            vec3 tint2 = vec3(1.0);

            #ifdef SHADOW_COLORED
                bool is_hit2 = trace_ray(ray, hit2, tint2);
            #else
                bool is_hit2 = trace_ray(ray, hit2);
            #endif

            if (!is_hit2) {
                vec3 skyLightColor = get_sun_color(hit_localPos, localSkyLightDir);
                sample_color += skyLightColor * tint2 * max(dot(hit_localNormal, localSkyLightDir), 0.0);

                // #ifdef CLOUDS_SHADOWS
                //     float cloudShadow = SampleCloudShadow(hit_localPos, localSkyLightDir);
                //     sample_color *= cloudShadow * 0.5 + 0.5;
                // #endif
            }
        #endif

        sample_color += hit_emission;

        final_color = hit_albedo * sample_color;
    }

    indirect_color += PI * final_color * tint;
}
