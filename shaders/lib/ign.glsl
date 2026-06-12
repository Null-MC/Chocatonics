float IGN() {
    return fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y));
}

float IGN(const in float seed) {
    return fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y) + seed);
}

float IGN_time(const in float time) {
    return fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y) + 51.9521 * time);
}

//float interleaved_gradientNoise(const in float temporal) {
//    return _ign(temporal);
//}

//float interleaved_gradientNoise() {
//    return interleaved_gradientNoise(frameTimeCounter * 51.9521);
//}

//float interleaved_gradientNoise(){
//    return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+tempOffsets);
//}
