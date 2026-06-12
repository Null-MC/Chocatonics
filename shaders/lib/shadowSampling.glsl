#ifdef SHADOW_PCF
    const vec2 shadowOffsets[4] = vec2[4](
        vec2( 0.1250,  0.0000),
        vec2(-0.1768, -0.1768),
        vec2(-0.0000,  0.3750),
        vec2( 0.3536, -0.3536));
#endif

//vec2 tapLocation_Shadow(int sampleNumber, int sampleCount, float nbRot, float spinAngle) {
//    float startJitter = spinAngle / 6.28;
//    float alpha = sqrt(sampleNumber + startJitter / sampleCount);
//    float angle = alpha * (nbRot * 6.28) + spinAngle*2.0;
//
//    return vec2(cos(angle), sin(angle)) * alpha;
//}

vec2 tapLocation_Shadow(int sampleNumber, int sampleCount, float nbRot, float jitter) {
    float alpha = (sampleNumber + jitter) / sampleCount;
    float angle = alpha * nbRot * 6.28 + jitter*6.28;

    return vec2(cos(angle), sin(angle)) * sqrt(alpha);
}
