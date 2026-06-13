#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


out VertexData {
	vec4 lmtexcoord;
	vec4 color;
} vOut;

uniform vec2 texelSize;
uniform int framemod8;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;


vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	vOut.lmtexcoord.xy = (gl_MultiTexCoord0).xy;

	vec2 lmcoord = gl_MultiTexCoord1.xy / 255.0;
	vOut.lmtexcoord.zw = lmcoord * lmcoord;

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
	bool istopv = worldpos.y > cameraPosition.y + 5.0;
	float ft = frameTimeCounter * 1.3;
	if (!istopv) position.xz += vec2(3.0, 1.0) + sin(ft) * sin(ft) * sin(ft) * vec2(2.1, 0.6);
	position.xz -= (vec2(3.0, 1.0) + sin(ft) * sin(ft) * sin(ft) * vec2(2.1, 0.6)) * 0.5;
	gl_Position = toClipSpace3(position);

	vOut.color = gl_Color;

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
