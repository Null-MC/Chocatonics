const float PI48 = 150.796447372 * WAVY_SPEED;
float pi2wt = PI48 * frameTimeCounter;


vec2 calcWave(const in vec3 pos) {
    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos), vec4(1.0, 0.005, 0.005, 0.005))) * 0.5 + 0.72) * 0.013;
    return (sin(pi2wt * vec2(0.0063, 0.0015) * 4.0 - pos.xz + pos.y * 0.05) + 0.1) * magnitude;
}

vec3 calcMovePlants(const in vec3 pos) {
    vec2 move1 = calcWave(pos);
    float move1y = -length(move1);
    return vec3(move1.x, move1y, move1.y) * 5.0*WAVY_STRENGTH;
}

vec3 calcWaveLeaves(const in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {
    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos), vec4(1.0, 0.005, 0.005, 0.005))) * 0.5 + 0.72) * 0.013;
    return (sin(pi2wt * vec3(0.0063, 0.0224, 0.0015) * 1.5 - pos)) * magnitude;
}

vec3 calcMoveLeaves(const in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWaveLeaves(pos, 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    return move1 * 5.0 * WAVY_STRENGTH;
}
