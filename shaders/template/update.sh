#!/bin/bash

./potater block  '../block.properties'  '../lib/blocks.glsl'   -t './block.properties'
./potater item   '../item.properties'   '../lib/items.glsl'    -t './item.properties'   -blocks '../lib/blocks.glsl'
# ./potater entity '../entity.properties' '../lib/entities.glsl' -t './entity.properties'
