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

#ifdef PHOTONICS_SHADOWS
    const float sunAngularRadius = 0.008;

    void buildOrthonormalBasis(vec3 v, out vec3 b1, out vec3 b2) {
        float sign = v.z >= 0.0 ? 1.0 : -1.0;
        float a = -1.0 / (sign + v.z);
        float b = v.x * v.y * a;
        b1 = vec3(1.0 + sign * v.x * v.x * a, sign * b, -sign * v.x);
        b2 = vec3(b, sign + v.y * v.y * a, -v.y);
    }

    vec3 getSampledSunDirection(vec3 dir, float radius, vec2 jitter) {
        float z = 1.0 - jitter.y * (1.0 - cos(radius));

        float sinTheta = sqrt(1.0 - z * z);
        float phi = 2.0 * PI * jitter.x;

        vec3 localDir = vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, z);

        vec3 tan, biTan;
        buildOrthonormalBasis(dir, tan, biTan);

        return tan * localDir.x + biTan * localDir.y + dir * localDir.z;
    }
#endif
