#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in vec4 mc_Entity;
in vec4 mc_midTexCoord;

out VertexData {
    vec2 texcoord;
} vOut;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform vec3 sunVec;
uniform float aspectRatio;
uniform float sunElevation;
uniform float lightSign;
uniform float cosFov;
uniform vec3 shadowViewDir;
uniform vec3 shadowCamera;
uniform vec3 shadowLightVec;
uniform float shadowMaxProj;

#include "/lib/Shadow_Params.glsl"
#include "/lib/windWaving.glsl"


bool intersectCone(float coneHalfAngle, vec3 coneTip , vec3 coneAxis, vec3 rayOrig, vec3 rayDir, float maxZ) {
    vec3 co = rayOrig - coneTip;
    float prod = dot(normalize(co),coneAxis);
    if (prod <= -coneHalfAngle) return true;   //In view frustrum

    float coneHalfAngle2 = coneHalfAngle*coneHalfAngle;
    float ray_dot_axis = dot(rayDir, coneAxis);
    float co_dot_axis = dot(co, coneAxis);

    float a = ray_dot_axis*ray_dot_axis - coneHalfAngle2;
    float b = 2.0 * (ray_dot_axis * co_dot_axis - dot(rayDir, co) * coneHalfAngle2);
    float c = co_dot_axis*co_dot_axis - dot(co, co) * coneHalfAngle2;

    float det = b*b - 4.0*a*c;
    if (det < 0.0) return false; // No intersection with either forward cone and backward cone

    det = sqrt(det);
    float t2 = (-b + det) / (2.0 * a);
    if (t2 <= 0.0 || t2 >= maxZ) return false; // Idk why it works

    return true;
}

vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), 1.0);
}


void main() {
	vec3 position = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);

    // Check if the vertice is going to cast shadows
    #ifdef SHADOW_FRUSTRUM_CULLING
        if (!intersectCone(cosFov, shadowCamera, shadowViewDir, position, -shadowLightVec, shadowMaxProj)) {
            gl_Position.xyzw = vec4(0.0, 0.0, 1e30, 0.0);  //Degenerates the triangle
            return;
        }
    #endif

    vOut.texcoord = gl_MultiTexCoord0.xy;

    #ifdef WAVY_PLANTS
        bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;

        if (mc_Entity.x == 10001 && istopv && length(position.xy) < 24.0) {
            vec3 localPos = mul3(shadowModelViewInverse, position);
            localPos += calcMovePlants(localPos + cameraPosition) / 255.0 * gl_MultiTexCoord1.y;
            position = mul3(shadowModelView, localPos);
        }

        if (mc_Entity.x == 10003 && length(position.xy) < 24.0) {
            vec3 localPos = mul3(shadowModelViewInverse, position);
            localPos += calcMoveLeaves(localPos + cameraPosition, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5)) / 255.0 * gl_MultiTexCoord1.y;
            position = mul3(shadowModelView, localPos);
        }
    #endif

    gl_Position = BiasShadowProjection(toClipSpace3(position));
    gl_Position.z /= 6.0;

    if (mc_Entity.x == 8 || mc_Entity.x == 9) gl_Position.w = -1.0;
}
