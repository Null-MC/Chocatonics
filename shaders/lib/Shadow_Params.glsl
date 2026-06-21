const float shadow_k = 1.8;
const float shadow_d0 = 0.04;
const float shadow_d1 = 0.61;


float shadow_a = exp(shadow_d0);
float shadow_b = (exp(shadow_d1) - shadow_a) * 150.0 / 128.0;

vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition) {
    float distortFactor = log(length(projectedShadowSpacePosition.xy) * shadow_b + shadow_a) * shadow_k;
    projectedShadowSpacePosition.xy /= distortFactor;
    return projectedShadowSpacePosition;
}

float calcDistort(vec2 worldpos) {
    return 1.0 / (log(length(worldpos) * shadow_b + shadow_a) * shadow_k);
}

bool IsInShadowMap(const in vec3 pos) {
    const float shadowTexel = 1.0 / shadowMapResolution;
    const vec3 shadowBounds = vec3(vec2(1.0 - shadowTexel), 6.0);

    return all(lessThan(abs(pos), shadowBounds));
}
