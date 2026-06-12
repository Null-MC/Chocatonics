vec3 toClipSpace3(const in vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 toScreenSpace(const in vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2.0 - 1.0;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

vec3 toScreenSpaceVector(const in vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2.0 - 1.0;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return normalize(fragposition.xyz);
}

vec3 toWorldSpace(const in vec3 p3) {
    return mul3(gbufferModelViewInverse, p3);
}

vec3 toWorldSpaceCamera(const in vec3 p3) {
    return toWorldSpace(p3) + cameraPosition;
}

vec3 toShadowSpace(const in vec3 p3) {
    return mul3(shadowModelView, toWorldSpace(p3));
}

vec3 toShadowSpaceProjected(const in vec3 p3) {
    return diagonal3(shadowProjection) * toShadowSpace(p3) + shadowProjection[3].xyz;
}
