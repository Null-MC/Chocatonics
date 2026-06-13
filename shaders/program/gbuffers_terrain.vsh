#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in vec4 mc_Entity;
in vec4 mc_midTexCoord;

#ifdef MC_NORMAL_MAP
	in vec4 at_tangent;
#endif

out VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec4 normalMat;

	#ifdef MAT_PARALLAX_ENABLED
		vec4 vtexcoordam; // .st for add, .pq for mul
		vec4 vtexcoord;
	#endif

	#ifdef MC_NORMAL_MAP
		vec4 tangent;
	#endif
} vOut;

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec2 texelSize;
uniform int framemod8;

#include "/lib/windWaving.glsl"


vec4 toClipSpace3(const in vec3 viewSpacePosition) {
	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
}


void main() {
	vOut.lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vOut.lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;

	#ifdef MAT_PARALLAX_ENABLED
		vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texcoordminusmid = vOut.lmtexcoord.xy - midcoord;
		vOut.vtexcoordam.pq  = abs(texcoordminusmid) * 2.0;
		vOut.vtexcoordam.st  = min(vOut.lmtexcoord.xy, midcoord - texcoordminusmid);
		vOut.vtexcoord.xy    = sign(texcoordminusmid) * 0.5 + 0.5;
	#endif

	vec3 position = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	vOut.color = gl_Color;

	bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;
	#ifdef MC_NORMAL_MAP
		vOut.tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
	#endif

	vOut.normalMat.xyz = normalize(gl_NormalMatrix * gl_Normal);
	vOut.normalMat.w = mc_Entity.x == 10004 || mc_Entity.x == 10003 || mc_Entity.x == 10001 ? 0.5 : 1.0;

	if (mc_Entity.x == 10006) vOut.normalMat.a = 0.6;

	#ifdef WAVY_PLANTS
		if ((mc_Entity.x == 10001 && istopv) && abs(position.z) < 64.0) {
    		vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
			worldpos.xyz += calcMovePlants(worldpos.xyz) * vOut.lmtexcoord.w - cameraPosition;
    		position = mul3(gbufferModelView, worldpos);
		}

		if (mc_Entity.x == 10003 && abs(position.z) < 64.0) {
    		vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz + cameraPosition;
			worldpos.xyz += calcMoveLeaves(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0, 0.2, 1.0), vec3(0.5, 0.1, 0.5)) * vOut.lmtexcoord.w - cameraPosition;
    		position = mul3(gbufferModelView, worldpos);
		}
	#endif

	if (mc_Entity.x == 10005) {
		vOut.color.rgb = normalize(vOut.color.rgb) * sqrt(3.0);
		vOut.normalMat.a = 0.9;
	}

	gl_Position = toClipSpace3(position);

	#ifdef SEPARATE_AO
		vOut.lmtexcoord.z *= sqrt(vOut.color.a);
		vOut.lmtexcoord.w *= vOut.color.a;
	#else
		vOut.color.rgb *= vOut.color.a;
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif

	#ifdef TAA_ENABLED
		gl_Position.xy += taa_offsets[framemod8] * gl_Position.w * texelSize;
	#endif
}
