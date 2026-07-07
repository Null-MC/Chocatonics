vec3 SampleHandLight(const in vec3 localPos, const in vec3 texLocalNormal, const in int heldItemId, const in int heldBlockLightValue) {
    vec3 lightColor = vec3(1.0);
    float lightRange = 0.0;

    if (heldItemId > 0) {
        GetBlockColorRange(heldItemId, lightColor, lightRange);
    }

    lightRange = max(lightRange, heldBlockLightValue);

    if (lightRange <= 0) return vec3(0.0);

    vec3 toLight = -relativeEyePosition - localPos;

    float lightDist = length(toLight);
    float att = 8.0 * (1.0 / (1.0 + square(lightDist)));

    vec3 playerLightDir = toLight / lightDist;
    float NoLm = max(dot(texLocalNormal, playerLightDir), 0.0);

    return NoLm * att * lightColor;
}
