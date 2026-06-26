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

#define worldToViewSpace(p) mul3(gbufferModelView, p)

#define toWorldSpace(p) mul3(gbufferModelViewInverse, p)
#define toWorldSpaceCamera(p) (toWorldSpace(p) + cameraPosition)

#define toShadowSpace(p) mul3(shadowModelView, p)
#define toShadowSpaceProjected(p) (diagonal3(shadowProjection) * (p) + shadowProjection[3].xyz)
#define worldToShadowSpaceProjected(p) toShadowSpaceProjected(toShadowSpace(p))
