#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


in vec4 mc_Entity;
in vec4 mc_midTexCoord;

#ifdef MAT_PBR_ENABLED
	in vec4 at_tangent;
#endif

out VertexData {
	vec4 lmtexcoord;
	vec4 color;
	vec3 normalMat;
	flat int blockId;

	#ifdef MAT_PARALLAX_ENABLED
		vec4 vtexcoordam; // .st for add, .pq for mul
		vec4 vtexcoord;
	#endif

	#ifdef MAT_PBR_ENABLED
		vec4 tangent;
	#endif
} vOut;

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec2 texelSize;
uniform int framemod8;

uniform mat4 gbufferProjectionInverse;

#include "/lib/blocks.glsl"
#include "/lib/projections.glsl"
#include "/lib/windWaving.glsl"


//vec4 toNdcSpace(const in vec3 viewSpacePosition) {
//	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
//}


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
	#ifdef MAT_PBR_ENABLED
		vOut.tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
	#endif

	vOut.normalMat = normalize(gl_NormalMatrix * gl_Normal);
//	vOut.normalMat.w = (mc_Entity.x == BLOCK_SSS || mc_Entity.x == BLOCK_PLANT_WAVING_FULL || mc_Entity.x == BLOCK_PLANT_WAVING_TOP) ? 0.5 : 1.0;
	vOut.blockId = int(mc_Entity.x);

//	if (mc_Entity.x == BLOCK_IDK) vOut.normalMat.a = 0.6;

	#ifdef WAVY_PLANTS
		if ((vOut.blockId == BLOCK_PLANT_WAVING_TOP && istopv) && abs(position.z) < 64.0) {
    		vec3 worldpos = toWorldSpaceCamera(position);
			worldpos.xyz += calcMovePlants(worldpos.xyz) * vOut.lmtexcoord.w - cameraPosition;
    		position = worldToViewSpace(worldpos);
		}

		if (vOut.blockId == BLOCK_PLANT_WAVING_FULL && abs(position.z) < 64.0) {
			vec3 worldpos = toWorldSpaceCamera(position);
			worldpos.xyz += calcMoveLeaves(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0, 0.2, 1.0), vec3(0.5, 0.1, 0.5)) * vOut.lmtexcoord.w - cameraPosition;
    		position = worldToViewSpace(worldpos);
		}
	#endif

//	if (mc_Entity.x == BLOCK_EMISSIVE) {
//		vOut.color.rgb = normalize(vOut.color.rgb) * sqrt(3.0);
//		vOut.normalMat.a = 0.9;
//	}

	gl_Position = viewToNdcSpace(gl_ProjectionMatrix, position);

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
