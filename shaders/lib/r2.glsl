// Low discrepancy 2D sequence, integration error is as low as sobol but easier to compute
// http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
vec2 R2_samples(float n) {
    const vec2 alpha = vec2(0.75487765, 0.56984026);
    return fract(alpha * n);
}

float R2_dither(const in vec2 coord, const in float time) {
    const vec2 alpha = vec2(0.75487765, 0.56984026);
    return fract(dot(alpha, coord) + 1.0/1.6180339887 * time);
}
