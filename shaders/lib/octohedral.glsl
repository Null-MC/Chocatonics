vec2 OctWrap(const in vec2 v) {
    return (1.0 - abs(v.yx)) * (step(0.0, v.xy) * 2.0 - 1.0);
}

vec2 OctEncode(vec3 n) {
    n /= sumOf(abs(n));
    n.xy = n.z >= 0.0 ? n.xy : OctWrap(n.xy);
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}

vec3 OctDecode(vec2 f) {
    f = f * 2.0 - 1.0;

    // https://twitter.com/Stubbesaurus/status/937994790553227264
    vec3 n = vec3(f.xy, 1.0 - sumOf(abs(f.xy)));
    float t = saturate(-n.z);
    n.xy += mix(vec2(t), vec2(-t), step(0.0, n.xy));
    return normalize(n);
}
