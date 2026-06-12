#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


attribute vec4 at_tangent;
attribute vec4 mc_Entity;

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
varying vec3 binormal;
varying vec3 tangent;
varying float dist;
varying vec3 viewVector;

uniform vec2 texelSize;
uniform int framemod8;
uniform mat4 gbufferModelViewInverse;

vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vec2 lmcoord = gl_MultiTexCoord1.xy / 255.0;
	lmtexcoord.zw = lmcoord;

	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	gl_Position = toClipSpace3(position);
	color = gl_Color;

	float mat = 0.0;
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		mat = 1.0;
		gl_Position.z -= 1e-4;
	}

	if (mc_Entity.x == 79.0) mat = 0.5;
	if (mc_Entity.x == 10002) mat = 0.01;

	normalMat = vec4(normalize(gl_NormalMatrix * gl_Normal), mat);

	tangent = normalize(gl_NormalMatrix * at_tangent.rgb);
	binormal = normalize(cross(tangent.rgb, normalMat.xyz) * at_tangent.w);

	mat3 tbnMatrix = mat3(
		tangent.x, binormal.x, normalMat.x,
		tangent.y, binormal.y, normalMat.y,
		tangent.z, binormal.z, normalMat.z);

	dist = length(gl_ModelViewMatrix * gl_Vertex);

	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
