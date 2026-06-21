#define NO_SHADOW_MAPPING

uniform sampler2D colortex4;

uniform vec3 sunPosition;
uniform float sunElevation;

#include "/lib/bicubic.glsl"
#include "/lib/sky_gradient.glsl"


#define PH_USE_CUSTOM_ALPHA
#define PH_ALPHA_FUNC(color) apply_tint_impl(color)

vec3 apply_tint_impl(vec4 color) {
    return vec3(1.0);// color.xyz * (1f - color.a);
}


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

//bool is_in_shadow_at(vec3 scene_pos, vec3 geo_normal, out vec3 shadow_color) {
//    // shadows
//    vec3 projectedShadowPosition = mul3(shadowModelView, hitLocalPos);
//    projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;
//
//    // apply distortion
//    float distortFactor = calcDistort(projectedShadowPosition.xy);
//    projectedShadowPosition.xy *= distortFactor;
//
//    vec3 shadow = vec3(1.0);
//    float hit_sky_NoLm = max(dot(hit_localNormal, sunPos), 0.0);
//
//    // do shadows only if on shadow map
//    if (!IsInShadowMap(projectedShadowPosition)) return false;
//
////    float rdMul = filtered.x * distortFactor * shadow_d0 * shadow_k / shadowMapResolution;
//    const float threshMul = max(2048.0 / shadowMapResolution * shadowDistance/128.0, 0.95);
//    float distortThresh = (sqrt(1.0 - square(hit_sky_NoLm)) / hit_sky_NoLm + 0.7) / distortFactor;
//
//    projectedShadowPosition = projectedShadowPosition * vec3(0.5, 0.5, 0.5/6.0) + vec3(0.5, 0.5, 0.5);
//
//    float rdMul = 4.0 / shadowMapResolution;
//    float diffthresh = distortThresh/6000.0 * threshMul;
//    float bias = 1.0 + noise.b * rdMul/SHADOW_FILTER_SAMPLE_COUNT * shadowMapResolution;
//    vec3 samplePos = vec3(projectedShadowPosition + vec3(0.0, 0.0, -diffthresh * bias));
//
//    shadow = vec3(texture(shadowtex0HW, samplePos));
//
//    // TODO: shadow color
//
//    shadow_color = vec3(shadow);
//    return true;
//}
