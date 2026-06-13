#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


attribute vec4 at_tangent;
attribute vec4 mc_Entity;

out VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;
	vec3 binormal;
	vec3 tangent;
	vec3 viewVector;
//	float dist;
} vOut;

uniform vec2 texelSize;
uniform int framemod8;
uniform mat4 gbufferModelViewInverse;

vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	vOut.lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vOut.lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;

	vec3 viewPos = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	gl_Position = toClipSpace3(viewPos);
	vOut.color = gl_Color;

	float mat = 0.0;
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		mat = 1.0;
		gl_Position.z -= 1.e-4;
	}

	if (mc_Entity.x == 79.0) mat = 0.5;
	if (mc_Entity.x == 10002) mat = 0.01;

	vOut.normalMat.xyz = normalize(gl_NormalMatrix * gl_Normal);
	vOut.normalMat.w = mat;

	vOut.tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vOut.binormal = normalize(cross(vOut.tangent, vOut.normalMat.xyz) * at_tangent.w);

	mat3 tbnMatrix = mat3(
		vOut.tangent.x, vOut.binormal.x, vOut.normalMat.x,
		vOut.tangent.y, vOut.binormal.y, vOut.normalMat.y,
		vOut.tangent.z, vOut.binormal.z, vOut.normalMat.z);

//	vOut.dist = length(viewPos);

	vOut.viewVector = normalize(tbnMatrix * viewPos.xyz);

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
