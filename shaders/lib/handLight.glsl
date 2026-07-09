#ifdef LIGHTING_COLORED
    void GetHandLightColorRange(const in int lightBlockId, const in int lightBlockRange, out vec3 lightColor, out float lightRange) {
        lightColor = vec3(1.0);
        lightRange = 0.0;

        if (lightBlockId > 0) {
            GetBlockColorRange(lightBlockId, lightColor, lightRange);
        }

        lightRange = max(lightRange, lightBlockRange);
    }

    vec3 SampleHandLight(const in vec3 localPos, const in vec3 localNormal, const in int heldItemId, const in int heldBlockLightValue) {
        float lightRange = 0.0;
        vec3 lightColor = vec3(1.0);
        GetHandLightColorRange(heldItemId, heldBlockLightValue, lightColor, lightRange);

        if (lightRange <= 0) return vec3(0.0);

        vec3 toLight = -relativeEyePosition - localPos;

        float lightDist = length(toLight);
        float att = 8.0 * (1.0 / (1.0 + square(lightDist)));

        vec3 lightDir = toLight / lightDist;
        float NoLm = max(dot(localNormal, lightDir), 0.0);

        return NoLm * att * lightColor;
    }
#else
    float SampleHandLight(const in vec3 localPos, const in vec3 localNormal) {
        vec3 toLight = -relativeEyePosition - localPos;
        float lightDist = length(toLight);

        float maxLit = max(heldBlockLightValue, heldBlockLightValue2);
        maxLit = max(maxLit - lightDist, 0.0) / 15.0;

        vec3 lightDir = toLight / lightDist;
        float NoLm = max(dot(localNormal, lightDir), 0.0);

        return NoLm * maxLit;
    }
#endif
