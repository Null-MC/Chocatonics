#version 430 compatibility

#include "/lib/common.glsl"
#include "/lib/settings.glsl"


layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
const ivec3 workGroups = ivec3(16, 16, 1);


layout(rgba8) uniform writeonly image2D imgBlockLight;

#include "/lib/blocks.glsl"


const vec3 color_White = vec3(255);
const vec3 color_Amethyst = vec3(118, 58, 201);
const vec3 color_Candle = vec3(230, 144, 76);
const vec3 color_CopperBulb = vec3(230, 204, 128);
const vec3 color_CopperLantern = vec3(107, 227, 191);
const vec3 color_CopperTorch = vec3(126, 230, 25);
const vec3 color_Fire = vec3(245, 117, 66);
const vec3 color_Furnace = vec3(196, 159, 114);
const vec3 color_RedstoneTorch = vec3(232, 59, 21);
const vec3 color_RespawnAnchor = vec3(99, 17, 165);
const vec3 color_SeaPickle = vec3(72, 100, 54);
const vec3 color_SoulFire = vec3(25, 184, 229);
//const vec3 color_Torch = vec3(245, 117, 66);

const vec3 color_CandleBlack = vec3(51, 51, 51);
const vec3 color_CandleBlue = vec3(0, 66, 255);
const vec3 color_CandleBrown = vec3(117, 67, 38);
const vec3 color_CandleCyan = vec3(0, 214, 214);
const vec3 color_CandleGray = vec3(84, 91, 99);
const vec3 color_CandleGreen = vec3(67, 115, 0);
const vec3 color_CandleLightBlue = vec3(39, 175, 255);
const vec3 color_CandleLightGray = vec3(161, 160, 159);
const vec3 color_CandleLime = vec3(112, 227, 0);
const vec3 color_CandleMagenta = vec3(193, 25, 207);
const vec3 color_CandleOrange = vec3(255, 117, 0);
const vec3 color_CandlePink = vec3(255, 141, 183);
const vec3 color_CandlePurple = vec3(145, 0, 255);
const vec3 color_CandleRed = vec3(219, 0, 0);
const vec3 color_CandleYellow = vec3(255, 224, 0);


uint blockId;

#define IS(id) (blockId == id)
#define RANGE(minId, maxId) (blockId >= minId && blockId <= maxId)


void main() {
    blockId = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * 256u;

    vec3 color = vec3(0.0);
    float range = 0.0;

    // LIGHTS

    if RANGE(BLOCK_LIGHT_1, BLOCK_LIGHT_15) {
        color = color_White;

        if IS(BLOCK_LIGHT_1) range = 1;
        if IS(BLOCK_LIGHT_2) range = 2;
        if IS(BLOCK_LIGHT_3) range = 3;
        if IS(BLOCK_LIGHT_4) range = 4;
        if IS(BLOCK_LIGHT_5) range = 5;
        if IS(BLOCK_LIGHT_6) range = 6;
        if IS(BLOCK_LIGHT_7) range = 7;
        if IS(BLOCK_LIGHT_8) range = 8;
        if IS(BLOCK_LIGHT_9) range = 9;
        if IS(BLOCK_LIGHT_10) range = 10;
        if IS(BLOCK_LIGHT_11) range = 11;
        if IS(BLOCK_LIGHT_12) range = 12;
        if IS(BLOCK_LIGHT_13) range = 13;
        if IS(BLOCK_LIGHT_14) range = 14;
        if IS(BLOCK_LIGHT_15) range = 15;
    }

    if RANGE(BLOCK_AMETHYST_BUD_MEDIUM, BLOCK_AMETHYST_CLUSTER) {
        color = color_Amethyst;

        if IS(BLOCK_AMETHYST_BUD_MEDIUM) range = 2;
        if IS(BLOCK_AMETHYST_BUD_LARGE) range = 4;
        if IS(BLOCK_AMETHYST_CLUSTER) range = 5;
    }

    if IS(BLOCK_BEACON) {
        color = color_White;
        range = 15;
    }

    if IS(BLOCK_BLAST_FURNACE_LIT) {
        color = color_Furnace;
        range = 6;
    }

    if IS(BLOCK_BREWING_STAND) {
        color = color_Furnace;
        range = 2;
    }

    if IS(BLOCK_CAMPFIRE_LIT) {
        color = color_Fire;
        range = 15;
    }

    if IS(BLOCK_CAVEVINE_BERRIES) {
        color = vec3(230, 120, 30);
        range = 14;
    }

    if RANGE(BLOCK_COPPER_BULB_LIT, BLOCK_COPPER_BULB_OXIDIZED_LIT) {
        color = color_CopperBulb;

        if IS(BLOCK_COPPER_BULB_LIT) range = 15;
        if IS(BLOCK_COPPER_BULB_EXPOSED_LIT) range = 12;
        if IS(BLOCK_COPPER_BULB_WEATHERED_LIT) range = 8;
        if IS(BLOCK_COPPER_BULB_OXIDIZED_LIT) range = 4;
    }

    if IS(BLOCK_COPPER_LANTERN) {
        color = color_CopperLantern;
        range = 15;
    }

    if IS(BLOCK_COPPER_TORCH) {
        color = color_CopperTorch;
        range = 14;
    }

    if IS(BLOCK_CRYING_OBSIDIAN) {
        color = vec3(99, 17, 165);
        range = 10;
    }

    if IS(BLOCK_END_ROD) {
        color = vec3(244, 237, 223);
        range = 14;
    }

    if IS(BLOCK_FIRE) {
        color = color_Fire;
        range = 15;
    }

    if RANGE(BLOCK_FROGLIGHT_OCHRE, BLOCK_FROGLIGHT_VERDANT) {
        range = 15;

        if IS(BLOCK_FROGLIGHT_OCHRE) color = vec3(196, 165, 28);
        if IS(BLOCK_FROGLIGHT_PEARLESCENT) color = vec3(188, 111, 168);
        if IS(BLOCK_FROGLIGHT_VERDANT) color = vec3(118, 195, 104);
    }

    if IS(BLOCK_FURNACE_LIT) {
        color = color_Furnace;
        range = 6;
    }

    if IS(BLOCK_GLOWSTONE) {
        color = vec3(199, 156, 113);
        range = 15;
    }

    if IS(BLOCK_JACK_O_LANTERN) {
        color = vec3(196, 179, 83);
        range = 15;
    }

    if IS(BLOCK_LANTERN) {
        color = vec3(181, 86, 51);
        range = 12;
    }

    if IS(BLOCK_LAVA) {
        color = vec3(color_Fire);
        range = 15;
    }

    if IS(BLOCK_LIGHTING_ROD_POWERED) {
        color = vec3(222, 244, 249);
        range = 8;
    }

    if IS(BLOCK_MAGMA) {
        color = vec3(190, 82, 28);
        range = 3;
    }

    if IS(BLOCK_NETHER_PORTAL) {
        color = vec3(128, 42, 212);
        range = 11;
    }

    if IS(BLOCK_REDSTONE_LAMP_LIT) {
        color = vec3(242, 198, 172);
        range = 15;
    }

    if IS(BLOCK_REDSTONE_ORE_LIT) {
        color = color_RedstoneTorch;
        range = 9;
    }

    if IS(BLOCK_REDSTONE_TORCH_LIT) {
        color = color_RedstoneTorch;
        range = 7;
    }

    if RANGE(BLOCK_RESPAWN_ANCHOR_1, BLOCK_RESPAWN_ANCHOR_4) {
        color = color_RespawnAnchor;

        if IS(BLOCK_RESPAWN_ANCHOR_1) range = 3;
        if IS(BLOCK_RESPAWN_ANCHOR_2) range = 7;
        if IS(BLOCK_RESPAWN_ANCHOR_3) range = 11;
        if IS(BLOCK_RESPAWN_ANCHOR_4) range = 15;
    }

    if IS(BLOCK_SCULK_CATALYST) {
        color = vec3(46, 91, 94);
        range = 6;
    }

    if IS(BLOCK_SEA_LANTERN) {
        color = vec3(141, 191, 219);
        range = 15;
    }

    if RANGE(BLOCK_SEA_PICKLE_WET_1, BLOCK_SEA_PICKLE_WET_4) {
        color = color_SeaPickle;

        if IS(BLOCK_SEA_PICKLE_WET_1) range = 6;
        if IS(BLOCK_SEA_PICKLE_WET_2) range = 9;
        if IS(BLOCK_SEA_PICKLE_WET_3) range = 12;
        if IS(BLOCK_SEA_PICKLE_WET_4) range = 15;
    }

    if IS(BLOCK_SHROOMLIGHT) {
        color = vec3(216, 120, 52);
        range = 15;
    }

    if IS(BLOCK_SMOKER_LIT) {
        color = color_Furnace;
        range = 6;
    }

    if IS(BLOCK_SOUL_CAMPFIRE_LIT) {
        color = color_SoulFire;
        range = 12;
    }

    if IS(BLOCK_SOUL_FIRE) {
        color = color_SoulFire;
        range = 12;
    }

    if IS(BLOCK_SOUL_LANTERN) {
        color = color_SoulFire;
        range = 12;
    }

    if IS(BLOCK_SOUL_TORCH) {
        color = color_SoulFire;
        range = 10;
    }

    if IS(BLOCK_TORCH) {
        color = color_Fire;
        range = 12;
    }

    // TINTED

    if IS(BLOCK_HONEY) color = vec3(251, 187, 64);
    if IS(BLOCK_SLIME) color = vec3(104, 185, 84);
    if IS(BLOCK_STAINED_GLASS_BLACK) color = vec3(77, 77, 77);
    if IS(BLOCK_STAINED_GLASS_BLUE) color = vec3(26, 26, 250);
    if IS(BLOCK_STAINED_GLASS_BROWN) color = vec3(144, 99, 38);
    if IS(BLOCK_STAINED_GLASS_CYAN) color = vec3(21, 136, 195);
    if IS(BLOCK_STAINED_GLASS_GRAY) color = vec3(102, 102, 102);
    if IS(BLOCK_STAINED_GLASS_GREEN) color = vec3(32, 206, 21);
    if IS(BLOCK_STAINED_GLASS_LIGHT_BLUE) color = vec3(82, 175, 244);
    if IS(BLOCK_STAINED_GLASS_LIGHT_GRAY) color = vec3(179, 179, 179);
    if IS(BLOCK_STAINED_GLASS_LIME) color = vec3(161, 236, 32);
    if IS(BLOCK_STAINED_GLASS_MAGENTA) color = vec3(178, 76, 216);
    if IS(BLOCK_STAINED_GLASS_ORANGE) color = vec3(234, 149, 47);
    if IS(BLOCK_STAINED_GLASS_PINK) color = vec3(242, 70, 127);
    if IS(BLOCK_STAINED_GLASS_PURPLE) color = vec3(147, 43, 231);
    if IS(BLOCK_STAINED_GLASS_RED) color = vec3(255, 48, 48);
    if IS(BLOCK_STAINED_GLASS_WHITE) color = vec3(245, 245, 245);
    if IS(BLOCK_STAINED_GLASS_YELLOW) color = vec3(246, 246, 31);
    if IS(BLOCK_TINTED_GLASS) color = vec3(51, 26, 51);

    // OTHER

    if IS(BLOCK_PLANT_WAVING_FULL) {
        //
    }

    // FINAL

    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    vec4 dataLight = vec4(color / 255.0, range / 32.0);
    imageStore(imgBlockLight, uv, dataLight);
}
