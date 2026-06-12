#ifdef SHADOW_PCF
    const vec2 shadowOffsets[4] = vec2[4](
        vec2( 0.1250,  0.0000),
        vec2(-0.1768, -0.1768),
        vec2(-0.0000,  0.3750),
        vec2( 0.3536, -0.3536));
#endif

vec2 tapLocation(int sampleNumber, float spinAngle, int nb, float nbRot) {
    float startJitter = spinAngle / 6.28;
    float alpha = sqrt(sampleNumber + startJitter/nb);
    float angle = alpha * (nbRot * 6.28) + spinAngle*2.0;

    return vec2(cos(angle), sin(angle)) * alpha;
}
