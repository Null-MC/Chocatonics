#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in vec4 at_tangent;
in vec4 mc_Entity;

out VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec3 normalMat;
	vec3 binormal;
	vec3 tangent;
	vec3 viewVector;
	flat int blockId;
} vOut;

uniform vec2 texelSize;
uniform int framemod8;
uniform mat4 gbufferModelViewInverse;

#include "/lib/blocks.glsl"


vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	vOut.lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vOut.lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;

	vec3 viewPos = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	gl_Position = toClipSpace3(viewPos);
	vOut.color = gl_Color;

//	float mat = 0.0;
	int blockId = int(mc_Entity.x);
//	if (mc_Entity.x == BLOCK_WATER || mc_Entity.x == 9.0) {
	if (blockId == BLOCK_WATER) {
//		mat = 1.0;
		gl_Position.z -= 1.e-4;
	}

//	if (mc_Entity.x == BLOCK_ICE) mat = 0.5;
//	if (mc_Entity.x == BLOCK_REFLECTIVE) mat = 0.01;

	vOut.normalMat.xyz = normalize(gl_NormalMatrix * gl_Normal);
	vOut.blockId = blockId;

	vOut.tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vOut.binormal = normalize(cross(vOut.tangent, vOut.normalMat.xyz) * at_tangent.w);

	mat3 tbnMatrix = mat3(
		vOut.tangent.x, vOut.binormal.x, vOut.normalMat.x,
		vOut.tangent.y, vOut.binormal.y, vOut.normalMat.y,
		vOut.tangent.z, vOut.binormal.z, vOut.normalMat.z);

	vOut.viewVector = normalize(tbnMatrix * viewPos.xyz);

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
