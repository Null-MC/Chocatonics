// encode normal in two channels (xy),torch(z) and sky lightmap (w)
vec4 encode(const in vec3 n) {
    return vec4(n.xy * inversesqrt(n.z * 8.0 + 8.0) + 0.5, vec2(lmtexcoord.z, lmtexcoord.w));
}

// encoding by jodie
float encodeVec2(const in vec2 a) {
    const vec2 constant1 = vec2(1.0, 256.0) / 65535.0;
    vec2 temp = floor(a * 255.0);
//    return temp.x*constant1.x+temp.y*constant1.y;
    return dot(temp, constant1);
}

float encodeVec2(const in float x, const in float y) {
    return encodeVec2(vec2(x, y));
}
