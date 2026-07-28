#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	vec4 color;
	vec4 normalMat;
	vec2 lmcoord;
	float viewDist;
} vOut;

uniform vec2 texelSize;
uniform int framemod8;
uniform mat4 gbufferModelViewInverse;


vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	vOut.lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	vec3 viewPos = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	gl_Position = toClipSpace3(viewPos);
	vOut.color = gl_Color;

	float mat = 0.0;
	//if (mc_Entity.x == BLOCK_WATER || mc_Entity.x == 9.0) {
	if (dhMaterialId == DH_BLOCK_WATER) {
		mat = 1.0;
		gl_Position.z -= 1.e-4;
	}

//	if (dhMaterialId == DH_BLOCK_ICE) mat = 0.5;
//	if (dhMaterialId == BLOCK_REFLECTIVE) mat = 0.01;

	vOut.normalMat.xyz = normalize(gl_NormalMatrix * gl_Normal);
	vOut.normalMat.w = mat;

	vOut.viewDist = length(viewPos);

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
