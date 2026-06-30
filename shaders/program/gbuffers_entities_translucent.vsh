#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in vec4 at_tangent;

out VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;

	#ifdef MAT_PBR_ENABLED
		vec4 tangent;
	#endif
} vOut;

uniform vec2 texelSize;
uniform int framemod8;
uniform mat4 gbufferModelViewInverse;

#include "/lib/projections.glsl"


void main() {
	vOut.lmtexcoord.xy = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	vOut.lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;

	vec3 viewPos = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	gl_Position = viewToNdcSpace(gl_ProjectionMatrix, viewPos);
	vOut.color = gl_Color;

	float mat = 0.0;

	vOut.normalMat.xyz = normalize(gl_NormalMatrix * gl_Normal);
	vOut.normalMat.w = mat;

	#ifdef MAT_PBR_ENABLED
		vOut.tangent.xyz = normalize(gl_NormalMatrix * at_tangent.xyz);
		vOut.tangent.w = at_tangent.w;
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
