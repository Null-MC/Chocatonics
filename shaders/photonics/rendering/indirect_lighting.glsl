#if defined(CLOUDS_SHADOWS) && !defined(PHOTONICS_GI_SHADOWMAP)
    uniform sampler2D noisetex;
#endif

uniform vec3 shadowLightPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform vec3 sunVec;

#include "/photonics/interface/lighting_interface.glsl"
#include "/photonics/tracing.glsl"
#include "/photonics/utility/random.glsl"

#include "/photonics/modifiers/indirect_surface_sample_modifier.glsl"
#include "/photonics/trace_ray.glsl"

#if defined(CLOUDS_SHADOWS) && !defined(PHOTONICS_GI_SHADOWMAP)
    #include "/lib/blueNoise.glsl"
#endif

#ifdef CLOUDS_SHADOWS
    #include "/lib/volumetricClouds.glsl"
#endif


void sample_indirect(inout vec3 indirect_color, vec3 sample_rt_pos, vec3 geo_normal, vec3 tex_normal, inout uint rnd_state,
    out vec3 first_hit, out vec3 first_normal) {

    vec3 trace_localDir = ph_rand_direction(rnd_state, tex_normal);

    RayIterator ray;
    ray.iterations = PHOTONICS_GI_STEPS;
    ray_iter_set_position(ray, sample_rt_pos);
    ray_iter_set_direction(ray, trace_localDir);
    ray_iter_offset_position(ray, 0.1 * geo_normal);

    RayResult hit;
    vec3 tint = vec3(1.0);

    #if PHOTONICS_TINTING > 0
        bool is_hit = trace_ray(ray, hit, tint);
    #else
        bool is_hit = trace_ray(ray, hit);
    #endif

    vec3 final_color = vec3(0.0);

    if (!is_hit) {
        #ifdef PHOTONICS_GI_ENABLED
            // hit sky
            vec3 playerPos = sample_rt_pos - rt_camera_position;
            final_color = get_sky_color(playerPos, trace_localDir);
        #endif

        first_hit = vec3(-1.0);
    }
    else {
        vec3 radiance = vec3(0.0);
        vec3 transmittance = vec3(1.0);

        #ifdef CLOUDS_SHADOWS
            float noise = blueNoise(gl_FragCoord.xy, frameCounter);
        #endif

        for (int bounce = 0; bounce < PH_MAX_GI_BOUNCES; bounce++) {
            VoxelData voxel_data = ray_result_voxel_data(hit);
            vec3 hit_albedo = voxel_data_albedo(voxel_data).rgb;
//            hit_albedo = toLinear(hit_albedo);

            vec3 hit_position = ray_result_position(hit);
            vec3 hit_localPos = hit_position - rt_camera_position;
            vec3 hit_localNormal = ray_result_normal(hit);

            if (bounce == 0) {
                first_hit = hit_position;
                first_normal = hit_localNormal;
            }

            vec3 sample_color = vec3(0.0);

            #ifdef PHOTONICS_GI_ENABLED
                vec3 localSkyLightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
                vec3 skyLightColor = get_sun_color(hit_localPos, localSkyLightDir);

                #ifdef PHOTONICS_GI_SHADOWMAP
                    vec3 sun_radiance;
                    if (sample_sun_color(hit_localPos, hit_localNormal, sun_radiance)) {
                        skyLightColor = sun_radiance;
                    }
                #else
                    // trace sun
                    RayIterator ray_sun;
                    ray_sun.iterations = 100; // TODO: setting?
                    ray_iter_set_position(ray_sun, hit_position);
                    ray_iter_set_direction(ray_sun, localSkyLightDir);
                    ray_iter_offset_position(ray_sun, 0.1 * hit_localNormal);

                    RayResult hit2;

                    #if PHOTONICS_TINTING > 0
                        vec3 shadowTint = vec3(1.0);
                        bool is_hit2 = trace_ray(ray_sun, hit2, shadowTint);
                        skyLightColor *= shadowTint;
                    #else
                        bool is_hit2 = trace_ray(ray_sun, hit2);
                    #endif

                    if (is_hit2) skyLightColor = vec3(0.0);
                #endif

                float skyShading = max(dot(hit_localNormal, localSkyLightDir), 0.0);

                #ifdef CLOUDS_SHADOWS
                    vec3 hit_worldPos = hit_localPos + cameraPosition;

                    const int rayMarchSteps = 6;
                    float cloudShadow = 0.0;

                    for (int i = 0; i < rayMarchSteps; i++) {
                        vec3 cloudPos = hit_worldPos + localSkyLightDir / abs(localSkyLightDir.y) * (1500 + (noise+i) / rayMarchSteps*1700 - hit_worldPos.y);
                        cloudShadow += getCloudDensity(cloudPos, 0);
                    }

                    cloudShadow = mix(1.0, exp(-cloudShadow * cloudDensity * 1700/rayMarchSteps), mix(CLOUDS_SHADOWS_STRENGTH, 1.0, rainStrength));
                    skyShading *= cloudShadow;
                #endif

                sample_color += skyLightColor * skyShading;
            #endif

            Light hit_light = ray_result_light_data(hit);
            if (light_is_valid(hit_light) && hit_light.type == LIGHT_TYPE_NOT_TRACED) {
                vec3 origin = floor(ray_result_position(hit)) + 0.5;
                vec3 light_color = light_sample_at(hit_light, sample_rt_pos, origin, geo_normal, geo_normal);
                sample_color += light_color;
            }

            float hit_NoVm = max(dot(hit_localNormal, -trace_localDir), 0.0);
            transmittance *= hit_albedo * hit_NoVm;
            radiance += transmittance * sample_color;

            trace_localDir = ph_rand_direction(rnd_state, hit_localNormal);

            ray_iter_set_direction(ray, trace_localDir);
            ray_iter_offset_position(ray, 0.1 * hit_localNormal);
        }

        final_color = radiance;
    }

    indirect_color += final_color * tint * 8.0/3.0;
}
