#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


//#ifdef MC_NORMAL_MAP
//	in vec4 at_tangent;
//#endif

out VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;

//	#ifdef MC_NORMAL_MAP
//		vec4 tangent;
//	#endif
} vOut;

uniform vec2 texelSize;
uniform int framemod8;


void main() {
	vOut.lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vOut.lmtexcoord.zw = gl_MultiTexCoord1.xy/255.0;
	vOut.normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), 1.0);
	vOut.color = gl_Color;

	gl_Position = ftransform();

//	#ifdef MC_NORMAL_MAP
//		vOut.tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
//	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
