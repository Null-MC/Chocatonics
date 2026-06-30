// FOR VERTEX TRANSFORMS!
#define viewToNdcSpace(m, p) (vec4(projMAD(m, p), -(p).z))

//vec4 toNdcSpace(const in vec3 viewSpacePosition) {
//    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
//}

#define toClipSpace3(p) (projMAD(gbufferProjection, (p)) / -(p).z * 0.5 + 0.5)
#define toClipSpace3_prev(p) (projMAD(gbufferPreviousProjection, (p)) / -(p).z * 0.5 + 0.5)

vec3 screenToViewSpace(const in mat4 matProjInv, in vec3 p) {
    p = p * 2.0 - 1.0;

	vec4 iProjDiag = vec4(matProjInv[0].x, matProjInv[1].y, matProjInv[2].zw);
    vec4 fragposition = iProjDiag * p.xyzz + matProjInv[3];
    return fragposition.xyz / fragposition.w;
}

//#define screenToViewSpace(p) toScreenSpace(gbufferProjectionInverse, p)

//vec3 screenToViewSpace(const in vec3 p) {
//    vec3 p3 = p * 2.0 - 1.0;
//
//    vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
//    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
//    return fragposition.xyz / fragposition.w;
//}

#define toScreenSpace(p) screenToViewSpace(gbufferProjectionInverse, p)

//vec3 toScreenSpaceVector(const in vec3 p) {
//	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
//    vec3 p3 = p * 2.0 - 1.0;
//    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
//    return normalize(fragposition.xyz);
//}

//#define worldToViewSpace(m, p) mul3(m, p)
#define worldToViewSpace(p) mul3(gbufferModelView, p)
#define worldToViewSpace_prev(p) mul3(gbufferPreviousModelView, p)

#define toWorldSpace(p) mul3(gbufferModelViewInverse, p)
#define toWorldSpace_prev(p) mul3(gbufferPreviousModelView, p)
#define toWorldSpaceCamera(p) (toWorldSpace(p) + cameraPosition)

#define toShadowSpace(p) mul3(shadowModelView, p)
#define toShadowSpaceProjected(p) (diagonal3(shadowProjection) * (p) + shadowProjection[3].xyz)
#define worldToShadowSpaceProjected(p) toShadowSpaceProjected(toShadowSpace(p))
