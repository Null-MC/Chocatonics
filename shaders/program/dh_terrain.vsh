#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	vec2 lmcoord;
	vec4 color;
	vec3 normalMat;
	flat int materialId;
} vOut;

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec2 texelSize;
uniform int framemod8;

#include "/lib/projections.glsl"


void main() {
//	vOut.lmcoord = gl_MultiTexCoord1.xy / 255.0;
	vOut.lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	vec3 position = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	vOut.color = gl_Color;

	vOut.normalMat = normalize(gl_NormalMatrix * gl_Normal);
	vOut.materialId = dhMaterialId;

	gl_Position = viewToNdcSpace(gl_ProjectionMatrix, position);

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
