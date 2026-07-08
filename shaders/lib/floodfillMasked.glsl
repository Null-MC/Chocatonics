bool IsVoxelSolid(const in ivec3 voxelPos) {
    uint voxelId = texelFetch(texVoxels, voxelPos, 0).r;

    uint solid_face_mask = GetBlockLightMask(texBlockLightMask, voxelId);
    return IsLightMaskSolid(solid_face_mask);
}

void extendCorner(inout vec2 pos) {
    pos *= max(minOf(0.5 / pos), 1.0);
}

vec3 SampleFloodFillMasked(const in vec3 voxelPos, const in int frame) {
    #ifdef LIGHTING_FLOODFILL_CORNER_FIX
        vec3 tf = fract(voxelPos);
        ivec3 vPos = ivec3(floor(voxelPos));

        // TODO: save memory and use uint bits
        bool x0 = IsVoxelSolid(vPos - ivec3(1,0,0));
        bool x1 = IsVoxelSolid(vPos + ivec3(1,0,0));
        bool y0 = IsVoxelSolid(vPos - ivec3(0,1,0));
        bool y1 = IsVoxelSolid(vPos + ivec3(0,1,0));
        bool z0 = IsVoxelSolid(vPos - ivec3(0,0,1));
        bool z1 = IsVoxelSolid(vPos + ivec3(0,0,1));

        // FACES
        if (x0) tf.x = max(tf.x, 0.5);
        if (x1) tf.x = min(tf.x, 0.5);
        if (y0) tf.y = max(tf.y, 0.5);
        if (y1) tf.y = min(tf.y, 0.5);
        if (z0) tf.z = max(tf.z, 0.5);
        if (z1) tf.z = min(tf.z, 0.5);

        // XZ CORNERS
        if (!x0 && !z0 && IsVoxelSolid(vPos - ivec3(1,0,1))) {
            extendCorner(tf.xz);
        }

        if (!x1 && !z1 && IsVoxelSolid(vPos + ivec3(1,0,1))) {
            tf.xz = 1.0 - tf.xz;
            extendCorner(tf.xz);
            tf.xz = 1.0 - tf.xz;
        }

        if (!x0 && !z1 && IsVoxelSolid(vPos + ivec3(-1,0,1))) {
            tf.z = 1.0 - tf.z;
            extendCorner(tf.xz);
            tf.z = 1.0 - tf.z;
        }

        if (!x1 && !z0 && IsVoxelSolid(vPos + ivec3(1,0,-1))) {
            tf.x = 1.0 - tf.x;
            extendCorner(tf.xz);
            tf.x = 1.0 - tf.x;
        }

        // XY CORNERS
        if (!x0 && !y0 && IsVoxelSolid(vPos - ivec3(1,1,0))) {
            tf.xy *= max(minOf(0.5 / tf.xy), 1.0);
        }

        if (!x1 && !y1 && IsVoxelSolid(vPos + ivec3(1,1,0))) {
            tf.xy = 1.0 - tf.xy;
            extendCorner(tf.xy);
            tf.xy = 1.0 - tf.xy;
        }

        if (!x0 && !y1 && IsVoxelSolid(vPos + ivec3(-1,1,0))) {
            tf.y = 1.0 - tf.y;
            extendCorner(tf.xy);
            tf.y = 1.0 - tf.y;
        }

        if (!x1 && !y0 && IsVoxelSolid(vPos + ivec3(1,-1,0))) {
            tf.x = 1.0 - tf.x;
            extendCorner(tf.xy);
            tf.x = 1.0 - tf.x;
        }

        // YZ CORNERS
        if (!y0 && !z0 && IsVoxelSolid(vPos - ivec3(0,1,1))) {
            extendCorner(tf.yz);
        }

        if (!y1 && !z1 && IsVoxelSolid(vPos + ivec3(0,1,1))) {
            tf.yz = 1.0 - tf.yz;
            extendCorner(tf.yz);
            tf.yz = 1.0 - tf.yz;
        }

        if (!y0 && !z1 && IsVoxelSolid(vPos + ivec3(0,-1,1))) {
            tf.z = 1.0 - tf.z;
            extendCorner(tf.yz);
            tf.z = 1.0 - tf.z;
        }

        if (!y1 && !z0 && IsVoxelSolid(vPos + ivec3(0,1,-1))) {
            tf.y = 1.0 - tf.y;
            extendCorner(tf.yz);
            tf.y = 1.0 - tf.y;
        }

        // TODO: DEBUG COORDS
        //return tf;

        vec3 texcoord = (vPos + tf) / VoxelBufferSize;
    #else
        vec3 texcoord = voxelPos / VoxelBufferSize;
    #endif

    texcoord.z *= 0.5;
    if (frame % 2 == 1) texcoord.z += 0.5;

    vec3 color = texture(texFloodFill, texcoord).rgb;
    return TransformFloodFillSample(color);
}