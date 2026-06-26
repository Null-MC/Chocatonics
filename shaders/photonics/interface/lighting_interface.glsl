#ifndef PHOTONICS_GI_SHADOWMAP
    #define NO_SHADOW_MAPPING
#endif

uniform sampler2D colortex4;

#ifdef PHOTONICS_GI_SHADOWMAP
    uniform sampler2D noisetex;
    uniform sampler2DShadow shadowtex0HW;

    #ifdef SHADOW_COLORED
        uniform sampler2D shadowcolor0;
        uniform sampler2DShadow shadowtex1HW;
    #endif
#endif

uniform vec3 sunPosition;
uniform float sunElevation;

#include "/lib/bicubic.glsl"
#include "/lib/sky_gradient.glsl"

#ifdef PHOTONICS_GI_SHADOWMAP
    #include "/lib/blueNoise.glsl"
    #include "/lib/Shadow_Params.glsl"
#endif


vec3 get_sun_direction() {
    vec3 localSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);

    return (float(sunElevation > 1.e-5) * 2.0 - 1.0) * localSunDir;
}

vec3 get_sun_color(vec3 playerPos, vec3 direction) {
    return texelFetch(colortex4, ivec2(6, 37), 0).rgb / 150.0;
}

vec3 get_sky_color(vec3 playerPos, vec3 direction) {
    vec3 color = skyCloudsFromTex(direction, colortex4).rgb / 150.0;
    return clamp(color * 8.0/3.0, 0.0, 65000.0);
}

#ifdef PHOTONICS_GI_SHADOWMAP
    bool sample_sun_color(vec3 player_pos, vec3 geo_normal, inout vec3 sun_radiance) {
        float noise = blueNoise(gl_FragCoord.xy, frameCounter);

        vec3 projectedShadowPosition = worldToShadowSpaceProjected(player_pos);

        // apply distortion
        float distortFactor = calcDistort(projectedShadowPosition.xy);
        projectedShadowPosition.xy *= distortFactor;

        vec3 sunDir = get_sun_direction();
        float hit_sky_NoLm = max(dot(geo_normal, sunDir), 0.0);

        // do shadows only if on shadow map
        if (!IsInShadowMap(projectedShadowPosition)) return false;

        const float threshMul = max(2048.0 / shadowMapResolution * shadowDistance/128.0, 0.95);
        float distortThresh = (sqrt(1.0 - square(hit_sky_NoLm)) / hit_sky_NoLm + 0.7) / distortFactor;

        projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);

        float rdMul = 4.0 / shadowMapResolution;
        float diffthresh = distortThresh/6000.0 * threshMul;
        float bias = 1.0 + noise * rdMul/SHADOW_FILTER_SAMPLE_COUNT * shadowMapResolution;
        vec3 samplePos = vec3(projectedShadowPosition + vec3(0.0, 0.0, -diffthresh * bias));

        vec3 sunColor = get_sun_color(player_pos, geo_normal);

        #ifdef SHADOW_COLORED
            float shadow = texture(shadowtex1HW, samplePos);
            float shadowColorF = texture(shadowtex0HW, samplePos);

            vec4 sampleColor = texture(shadowcolor0, samplePos.xy);
            sampleColor.rgb = mix(sampleColor.rgb, vec3(1.0), shadowColorF);

            sunColor *= InputTransform(sampleColor.rgb);
        #else
            float shadow = texture(shadowtex0HW, samplePos);
        #endif

        sun_radiance = shadow * sunColor;
        return true;
    }
#endif
