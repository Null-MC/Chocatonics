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

uniform usampler2D texBlockMeta;

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec2 texelSize;
uniform int framemod8;

uniform mat4 gbufferProjectionInverse;

#include "/lib/blocks.glsl"
#include "/lib/blockMeta.glsl"
#include "/lib/projections.glsl"
#include "/lib/windWaving.glsl"


//vec4 toNdcSpace(const in vec3 viewSpacePosition) {
//	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), -viewSpacePosition.z);
//}


void main() {
	vOut.blockId = int(mc_Entity.x);

	#if PHOTONICS_3D_BLOCKS == PH_VOXEL_FULL
		bool _discard = true;
	#elif PHOTONICS_3D_BLOCKS == PH_VOXEL_HYBRID
		bool _discard = false;
	#endif

	vOut.lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	vOut.lmtexcoord.zw = gl_MultiTexCoord1.xy / 255.0;

	#ifdef MAT_PARALLAX_ENABLED
		vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texcoordminusmid = vOut.lmtexcoord.xy - midcoord;
		vOut.vtexcoordam.pq  = abs(texcoordminusmid) * 2.0;
		vOut.vtexcoordam.st  = min(vOut.lmtexcoord.xy, midcoord - texcoordminusmid);
		vOut.vtexcoord.xy    = sign(texcoordminusmid) * 0.5 + 0.5;
	#endif

	vec3 viewPos = mul3(gl_ModelViewMatrix, gl_Vertex.xyz);
	vec3 localPos = toWorldSpace(viewPos);
	vOut.color = gl_Color;

	#if PHOTONICS_3D_BLOCKS == PH_VOXEL_HYBRID
		// TODO: fancier non-axis-aligned check
		vec3 pos_snapped = fract(localPos) + fract(cameraPosition);
//			vec3 f = fract()

		if (vOut.blockId == BLOCK_PLANT_WAVING_TOP || vOut.blockId == BLOCK_LEAVES) {
			_discard = true;
		}
	#endif

	#if PHOTONICS_3D_BLOCKS != PH_VOXEL_NONE
		if (_discard) {
			gl_Position = vec4(-2.0);
			return;
		}
	#endif

	bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;
	#ifdef MAT_PBR_ENABLED
		vOut.tangent = vec4(normalize(gl_NormalMatrix * at_tangent.rgb), at_tangent.w);
	#endif

	vOut.normalMat = normalize(gl_NormalMatrix * gl_Normal);
//	vOut.normalMat.w = (mc_Entity.x == BLOCK_SSS_HIGH || mc_Entity.x == BLOCK_PLANT_WAVING_FULL || mc_Entity.x == BLOCK_PLANT_WAVING_TOP) ? 0.5 : 1.0;

//	if (mc_Entity.x == BLOCK_SSS_LOW) vOut.normalMat.a = 0.6;

	#ifdef WAVY_PLANTS
		vec3 worldPos = localPos + cameraPosition;

		uint blockMeta = SampleBlockMeta(vOut.blockId);

//		if ((vOut.blockId == BLOCK_PLANT_WAVING_TOP && istopv) && abs(viewPos.z) < 64.0) {
		if (hasBit(blockMeta, BIT_WAVING_TOP) && istopv && abs(viewPos.z) < 64.0) {
			worldPos += calcMovePlants(worldPos) * vOut.lmtexcoord.w;
		}

		if (hasBit(blockMeta, BIT_WAVING_FULL) && abs(viewPos.z) < 64.0) {
			worldPos += calcMoveLeaves(worldPos, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0, 0.2, 1.0), vec3(0.5, 0.1, 0.5)) * vOut.lmtexcoord.w;
		}

		viewPos = worldToViewSpace(worldPos - cameraPosition);
	#endif

//	if (mc_Entity.x == BLOCK_EMISSIVE) {
//		vOut.color.rgb = normalize(vOut.color.rgb) * sqrt(3.0);
//		vOut.normalMat.a = 0.9;
//	}

	gl_Position = viewToNdcSpace(gl_ProjectionMatrix, viewPos);

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
