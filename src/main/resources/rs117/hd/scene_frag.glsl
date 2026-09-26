/*
 * Copyright (c) 2018, Adam <Adam@sigterm.info>
 * Copyright (c) 2021, 117 <https://twitter.com/117scape>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#version 330

#define DISPLAY_BASE_COLOR 0
#define DISPLAY_UV 0
#define DISPLAY_NORMAL 0
#define DISPLAY_TANGENT 0
#define DISPLAY_SHADOWS 0
#define DISPLAY_LIGHTING 0

#include <uniforms/global.glsl>
#include <uniforms/world_views.glsl>
#include <uniforms/materials.glsl>
#include <uniforms/water_types.glsl>

#include MATERIAL_CONSTANTS

uniform sampler2DArray textureArray;
uniform sampler2D shadowMap;
uniform usampler2DArray tiledLightingArray;

// general HD settings

flat in int fWorldViewId;
flat in ivec3 fAlphaBiasHsl;
flat in ivec3 fMaterialData;
flat in ivec3 fTerrainData;

#if FLAT_SHADING && ZONE_RENDERER
    flat in vec3 fFlatNormal;
#endif

in FragmentData {
    vec3 position;
    vec2 uv;
    vec3 normal;
    vec3 texBlend;
} IN;

out vec4 FragColor;

vec2 worldUvs(float scale) {
    return -IN.position.xz / (128 * scale);
}

vec2 auroraWorldXz() {
    return IN.position.xz + auroraWeatherWorldOffset;
}

vec2 auroraDetailXz() {
    return auroraWorldDetailPass != 0 ? auroraWorldXz() : IN.position.xz;
}

#include <utils/constants.glsl>
#include <utils/misc.glsl>
#include <utils/color_blindness.glsl>
#include <utils/caustics.glsl>
#include <utils/color_utils.glsl>
#include <utils/normals.glsl>
#include <utils/specular.glsl>
#include <utils/displacement.glsl>
#include <utils/shadows.glsl>
#include <utils/water.glsl>
#include <utils/color_filters.glsl>
#include <utils/fog.glsl>
#include <utils/wireframe.glsl>
#include <utils/lights.glsl>

// Aurora uses world-space noise so detail remains anchored while the camera moves.
float auroraHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float auroraNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(auroraHash(i), auroraHash(i + vec2(1, 0)), f.x),
               mix(auroraHash(i + vec2(0, 1)), auroraHash(i + vec2(1, 1)), f.x), f.y);
}

float auroraFbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; ++i) {
        value += auroraNoise(p) * amplitude;
        p = p * 2.03 + 17.1;
        amplitude *= 0.5;
    }
    return value;
}

float auroraCloudField(vec2 worldPosition) {
    vec2 windDir = normalize(vec2(cos(auroraWindDirection), sin(auroraWindDirection)) + vec2(0.001));
    vec2 wind = windDir * elapsedTime * mix(58.0, 132.0, auroraWindStrength);
    vec2 p = (worldPosition + wind) / 980.0;
    float broad = auroraFbm(p);
    float detail = auroraFbm(p * 2.37 + vec2(9.2, -4.7));
    // Match the denser visible sky: increasing cover creates more shadow islands.
    float threshold = mix(0.68, 0.31, auroraCloudCover);
    float field = broad * 0.72 + detail * 0.28;
    float cloud = smoothstep(threshold, threshold + 0.17, field);
    float veil = auroraFbm(p * 0.42 + vec2(-7.0, 19.0));
    float highCoverVeil = smoothstep(0.62, 0.88, auroraCloudCover) * smoothstep(0.36, 0.82, veil);
    cloud = clamp(max(cloud, highCoverVeil * 0.72), 0.0, 1.0);
    return cloud;
}

float auroraTime() {
    float automaticAdvance = elapsedTime * mix(0.00002, 0.00055, auroraDayCycleSpeed);
    return fract(auroraTimeOfDay + (auroraDayCycleEnabled != 0 ? automaticAdvance : 0.0));
}

float auroraMapMatch(Material material, int colorMap) {
    return colorMap >= 0 && material.colorMap == colorMap ? 1.0 : 0.0;
}

float auroraSnowMaterial(Material material) {
    return auroraMapMatch(material, MAT_AURORA_SNOW.colorMap);
}

float auroraFlatGrassMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_GRASS_1.colorMap) +
        auroraMapMatch(material, MAT_GRASS_2.colorMap) +
        auroraMapMatch(material, MAT_GRASS_3.colorMap) +
        auroraMapMatch(material, MAT_AURORA_GRASS_1.colorMap) +
        auroraMapMatch(material, MAT_AURORA_GRASS_2.colorMap) +
        auroraMapMatch(material, MAT_AURORA_GRASS_3.colorMap), 0.0, 1.0);
}

float auroraBroadleafMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_LEAVES_SIDE.colorMap) +
        auroraMapMatch(material, MAT_LEAVES_SIDE_ALT.colorMap) +
        auroraMapMatch(material, MAT_LEAVES_TOP.colorMap) +
        auroraMapMatch(material, MAT_LEAVES_TOP_ALT.colorMap) +
        auroraMapMatch(material, MAT_LEAVES_1.colorMap) +
        // Most 117-authored ordinary trees, conifers, bushes and plants use the
        // geometric LEAF_VEINS family rather than the vanilla leaf sheets.  The
        // 0.23 pass omitted it, which is why its tree change was almost invisible.
        auroraMapMatch(material, MAT_LEAF_VEINS.colorMap) +
        auroraMapMatch(material, MAT_AURORA_FOLIAGE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_LEAVES_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_LEAVES_TOP.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_DENSE_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_DENSE_TOP.colorMap) +
        auroraMapMatch(material, MAT_AURORA_OAK_LEAVES_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_OAK_LEAVES_TOP.colorMap) +
        auroraMapMatch(material, MAT_AURORA_FOLIAGE_AUTUMN.colorMap) +
        auroraMapMatch(material, MAT_AURORA_LEAF_VEINS.colorMap) +
        auroraMapMatch(material, MAT_AURORA_LEAF_VEINS_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_AURORA_LEAF_VEINS_VERY_LIGHT.colorMap), 0.0, 1.0);
}

float auroraWillowMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_WILLOW_LEAVES.colorMap) +
        auroraMapMatch(material, MAT_SEASONLESS_WILLOW_LEAVES.colorMap) +
        auroraMapMatch(material, MAT_AUTUMN_WILLOW_LEAVES.colorMap) +
        auroraMapMatch(material, MAT_WINTER_WILLOW_LEAVES.colorMap), 0.0, 1.0);
}

float auroraEvergreenMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_LEAFY_STONEPINE01.colorMap) +
        auroraMapMatch(material, MAT_AURORA_LEAF_VEINS_DARK.colorMap) +
        auroraMapMatch(material, MAT_AURORA_LEAF_VEINS_DARKER.colorMap) +
        auroraMapMatch(material, MAT_AURORA_LEAF_VEINS_DARKEST.colorMap), 0.0, 1.0);
}

float auroraYewMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_AURORA_YEW_LEAVES_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_LEAVES_TOP.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_AUTUMN_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_AUTUMN_TOP.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_WINTER_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_WINTER_TOP.colorMap), 0.0, 1.0);
}

float auroraYewSeasonMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_AURORA_YEW_AUTUMN_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_AUTUMN_TOP.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_WINTER_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_YEW_WINTER_TOP.colorMap), 0.0, 1.0);
}

float auroraOakMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_AURORA_OAK_LEAVES_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_OAK_LEAVES_TOP.colorMap), 0.0, 1.0);
}

float auroraSmallTreeMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_LEAVES_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_LEAVES_TOP.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_DENSE_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SMALL_TREE_DENSE_TOP.colorMap), 0.0, 1.0);
}

float auroraMapleMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_MAPLE_LEAVES.colorMap) +
        auroraMapMatch(material, MAT_SEASONLESS_MAPLE_LEAVES.colorMap) +
        auroraMapMatch(material, MAT_WINTER_MAPLE_LEAVES.colorMap) +
        auroraMapMatch(material, MAT_AURORA_MAPLE_LEAVES.colorMap) +
        auroraMapMatch(material, MAT_AURORA_MAPLE_SUMMER.colorMap), 0.0, 1.0);
}

float auroraMagicLeavesMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_AURORA_MAGIC_LEAVES_SIDE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_MAGIC_LEAVES_TOP.colorMap), 0.0, 1.0);
}

float auroraHedgeMaterial(Material material) {
    return auroraMapMatch(material, MAT_AURORA_HEDGE_LEAVES.colorMap);
}

float auroraBarkMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_BARK.colorMap) +
        auroraMapMatch(material, MAT_LIGHT_BARK.colorMap) +
        auroraMapMatch(material, MAT_SEMI_LIGHT_BARK.colorMap) +
        auroraMapMatch(material, MAT_VERY_LIGHT_BARK.colorMap) +
        auroraMapMatch(material, MAT_BARK_STONEPINE.colorMap) +
        auroraMapMatch(material, MAT_BARK_STONEPINE_2.colorMap) +
        auroraMapMatch(material, MAT_AURORA_BARK.colorMap) +
        auroraMapMatch(material, MAT_AURORA_BARK_DETAIL.colorMap) +
        auroraMapMatch(material, MAT_AURORA_BARK_DETAIL_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_AURORA_BARK_DETAIL_PINE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_PINE_BARK.colorMap), 0.0, 1.0);
}

float auroraMagicMaterial(Material material) {
    return auroraMapMatch(material, MAT_MAGIC_STARS.colorMap);
}

float auroraPropWoodMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_CRATE.colorMap) +
        auroraMapMatch(material, MAT_HD_CRATE.colorMap) +
        auroraMapMatch(material, MAT_BOOKCASE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_WOOD.colorMap), 0.0, 1.0);
}

float auroraMetalMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_METALLIC_1.colorMap) +
        auroraMapMatch(material, MAT_METALLIC_2.colorMap) +
        auroraMapMatch(material, MAT_AURORA_METAL.colorMap) +
        auroraMapMatch(material, MAT_AURORA_IRON_BARS.colorMap), 0.0, 1.0);
}

float auroraIronBarsMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_IRON_BARS.colorMap) +
        auroraMapMatch(material, MAT_HD_IRON_BARS.colorMap) +
        auroraMapMatch(material, MAT_AURORA_IRON_BARS.colorMap), 0.0, 1.0);
}

float auroraHayMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_HAY.colorMap) +
        auroraMapMatch(material, MAT_HD_HAY.colorMap) +
        auroraMapMatch(material, MAT_HD_HAY_BRIGHT.colorMap) +
        auroraMapMatch(material, MAT_AURORA_HAY.colorMap), 0.0, 1.0);
}

float auroraFountainMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_WATER_FOUNTAIN_FLAT.colorMap) +
        auroraMapMatch(material, MAT_WATER_FOUNTAIN_FLAT_LIGHT.colorMap), 0.0, 1.0);
}

float auroraRoofMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_AURORA_ROOF_SHINGLE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROOF_SLATE.colorMap), 0.0, 1.0);
}

float auroraRockMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_ROCK_1.colorMap) +
        auroraMapMatch(material, MAT_ROCK_1_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_1_LIGHT_SMOOTH.colorMap) +
        auroraMapMatch(material, MAT_ROCK_2.colorMap) +
        auroraMapMatch(material, MAT_ROCK_2_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_MEDIUM_DARK.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_DARK.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_VERY_LIGHT_SMOOTH.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_SMOOTH.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_SEMI_SMOOTH.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_SMOOTH_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_3_SEMI_SMOOTH_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_4.colorMap) +
        auroraMapMatch(material, MAT_ROCK_4_DARK.colorMap) +
        auroraMapMatch(material, MAT_ROCK_5.colorMap) +
        auroraMapMatch(material, MAT_ROCK_5_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_6.colorMap) +
        auroraMapMatch(material, MAT_ROCK_6_DARK.colorMap) +
        auroraMapMatch(material, MAT_ROCK_6_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_6_VERY_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_ROCK_7.colorMap) +
        auroraMapMatch(material, MAT_ROCK_7_LIGHT.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROCK_1.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROCK_2.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROCK_3.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROCK_4.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROCK_5.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROCK_6.colorMap) +
        auroraMapMatch(material, MAT_AURORA_ROCK_7.colorMap), 0.0, 1.0);
}

float auroraStoneLikeMaterial(Material material) {
    return clamp(
        auroraMapMatch(material, MAT_AURORA_STONE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_STONEWORK.colorMap) +
        auroraMapMatch(material, MAT_AURORA_MASONRY.colorMap) +
        auroraMapMatch(material, MAT_AURORA_CONCRETE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_MARBLE.colorMap) +
        auroraMapMatch(material, MAT_AURORA_GRAVEL.colorMap) +
        auroraMapMatch(material, MAT_AURORA_SNOW.colorMap) +
        auroraMapMatch(material, MAT_AURORA_TILE.colorMap), 0.0, 1.0);
}

float auroraWettableMaterial(Material material) {
    return clamp(
        auroraRockMaterial(material) +
        auroraStoneLikeMaterial(material) +
        auroraMapMatch(material, MAT_AURORA_WOOD.colorMap), 0.0, 1.0);
}

float auroraFoliageMaterial(Material material) {
    return clamp(
        auroraBroadleafMaterial(material) +
        auroraWillowMaterial(material) +
        auroraEvergreenMaterial(material) +
        auroraYewMaterial(material) +
        auroraMapleMaterial(material) +
        auroraMagicLeavesMaterial(material) +
        auroraHedgeMaterial(material), 0.0, 1.0);
}

void main() {
    vec3 downDir = vec3(0, -1, 0);
    // View & light directions are from the fragment to the camera/light
    vec3 viewDir = normalize(cameraPos - IN.position);

    Material material1 = getMaterial(fMaterialData[0] >> MATERIAL_INDEX_SHIFT & MATERIAL_INDEX_MASK);
    Material material2 = getMaterial(fMaterialData[1] >> MATERIAL_INDEX_SHIFT & MATERIAL_INDEX_MASK);
    Material material3 = getMaterial(fMaterialData[2] >> MATERIAL_INDEX_SHIFT & MATERIAL_INDEX_MASK);

    // Water data
    bool isTerrain = (fTerrainData[0] & 1) != 0; // 1 = 0b1
    int waterDepth1 = fTerrainData[0] >> 11 & 0xFFF;
    int waterDepth2 = fTerrainData[1] >> 11 & 0xFFF;
    int waterDepth3 = fTerrainData[2] >> 11 & 0xFFF;
    float waterDepth =
        waterDepth1 * IN.texBlend.x +
        waterDepth2 * IN.texBlend.y +
        waterDepth3 * IN.texBlend.z;
    int waterTypeIndex = isTerrain ? fTerrainData[0] >> 3 & 0xFF : 0;
    WaterType waterType = getWaterType(waterTypeIndex);

    // set initial texture map ids
    int colorMap1 = material1.colorMap;
    int colorMap2 = material2.colorMap;
    int colorMap3 = material3.colorMap;

    // only use one flowMap map
    int flowMap = material1.flowMap;

    bool isUnderwater = waterDepth != 0;
    bool isWater = waterTypeIndex > 0 && !isUnderwater;

    vec4 outputColor = vec4(1);

    if (isWater) {
        outputColor = sampleWater(waterTypeIndex, viewDir);
    } else {
        vec2 blendedUv = IN.uv;

        float mipBias = 0;
        // Vanilla tree textures rely on UVs being clamped horizontally, which HD doesn't do at the texture level.
        // Instead we manually clamp vanilla textures with transparency here. Including the transparency check
        // allows texture wrapping to work correctly for the mirror shield.
        if ((fMaterialData[0] >> MATERIAL_FLAG_VANILLA_UVS & 1) == 1 && getMaterialHasTransparency(material1))
            blendedUv.x = clamp(blendedUv.x, 0, .984375);

        vec2 uv1 = blendedUv;
        vec2 uv2 = blendedUv;
        vec2 uv3 = blendedUv;

        // Scroll UVs
        uv1 += material1.scrollDuration * elapsedTime;
        uv2 += material2.scrollDuration * elapsedTime;
        uv3 += material3.scrollDuration * elapsedTime;

        // Scale from the center
        uv1 = (uv1 - .5) * material1.textureScale.xy + .5;
        uv2 = (uv2 - .5) * material2.textureScale.xy + .5;
        uv3 = (uv3 - .5) * material3.textureScale.xy + .5;

			// Bend long repeated rows in inherited ground textures without moving geometry.
			// Two low-frequency world-space fields prevent the warp itself from becoming directional.
			if (auroraEnabled != 0 && isTerrain && !isUnderwater && auroraMaterialDepth > 0.0) {
				vec2 warpCell = auroraDetailXz() / 310.0;
				vec2 terrainWarp = vec2(
					auroraFbm(warpCell + vec2(13.4, 2.1)),
					auroraFbm(warpCell * 1.17 + vec2(-8.2, 19.6))) - 0.5;
			terrainWarp *= 0.045 * auroraMaterialDepth;
			uv1 += terrainWarp;
			uv2 += terrainWarp * vec2(-0.82, 1.13);
			uv3 += terrainWarp * vec2(1.08, -0.76);
		}

        // get flowMap map
        vec2 flowMapUv = uv1 - animationFrame(material1.flowMapDuration);
        float flowMapStrength = material1.flowMapStrength;
        if (isUnderwater)
        {
            // Distort underwater textures
            flowMapUv = worldUvs(1.5) + animationFrame(10 * waterType.duration) * vec2(1, -1);
            flowMapStrength = 0.075;
        }

        vec2 uvFlow = texture(textureArray, vec3(flowMapUv, flowMap)).xy;
        uv1 += uvFlow * flowMapStrength;
        uv2 += uvFlow * flowMapStrength;
        uv3 += uvFlow * flowMapStrength;

        // Set up tangent-space transformation matrix

        vec3 N;
        #if FLAT_SHADING && ZONE_RENDERER
            N = normalize(fFlatNormal);
        #else
            N = normalize(IN.normal);
        #endif
        mat3 TBN = cotangent_frame(N, IN.position, IN.uv * -1.0);

        #if DISPLAY_UV
            FragColor = vec4(fract(uv1 * IN.texBlend.x + uv2 * IN.texBlend.y + uv3 * IN.texBlend.z), 0.0, 1.0);
            if (DISPLAY_UV == 1) return; // Redundant, for syntax highlighting in IntelliJ
        #endif

        #if DISPLAY_NORMAL
            FragColor = vec4(N * 0.5 + 0.5, 1.0);
            if (DISPLAY_NORMAL == 1) return; // Redundant, for syntax highlighting in IntelliJ
        #endif

        #if DISPLAY_TANGENT
            FragColor = vec4(TBN[0] * 0.5 + 0.5, 1.0);
            if (DISPLAY_TANGENT == 1) return; // Redundant, for syntax highlighting in IntelliJ
        #endif

        float selfShadowing = 0;
        vec3 fragPos = IN.position;
        #if PARALLAX_OCCLUSION_MAPPING
            mat3 invTBN = inverse(TBN);
            vec3 tsViewDir = invTBN * viewDir;
            vec3 tsLightDir = invTBN * -lightDir;

            vec3 fragDelta = vec3(0);

            sampleDisplacementMap(material1, tsViewDir, tsLightDir, uv1, fragDelta, selfShadowing);
            sampleDisplacementMap(material2, tsViewDir, tsLightDir, uv2, fragDelta, selfShadowing);
            sampleDisplacementMap(material3, tsViewDir, tsLightDir, uv3, fragDelta, selfShadowing);

            // Average
            fragDelta /= 3;
            selfShadowing /= 3;

            // Prevent displaced surfaces from casting flat shadows onto themselves
            fragDelta.z = max(0, fragDelta.z);

            fragPos += TBN * fragDelta;
        #endif

        vec3 hsl1 = unpackRawHsl(fAlphaBiasHsl[0]);
        vec3 hsl2 = unpackRawHsl(fAlphaBiasHsl[1]);
        vec3 hsl3 = unpackRawHsl(fAlphaBiasHsl[2]);

        // Apply entity tint to HSL
        ivec4 tint = getWorldViewTint(fWorldViewId);
        if (tint.w > 0) {
            hsl1 += ((tint.xyz - hsl1) * tint.w) / 128;
            hsl2 += ((tint.xyz - hsl2) * tint.w) / 128;
            hsl3 += ((tint.xyz - hsl3) * tint.w) / 128;
        }

        // get vertex colors
        vec4 baseColor1 = vec4(convertHsl(hsl1), 1 - float(fAlphaBiasHsl[0] >> 24 & 0xff) / 255.);
        vec4 baseColor2 = vec4(convertHsl(hsl2), 1 - float(fAlphaBiasHsl[1] >> 24 & 0xff) / 255.);
        vec4 baseColor3 = vec4(convertHsl(hsl3), 1 - float(fAlphaBiasHsl[2] >> 24 & 0xff) / 255.);

        // Convert to linear RGB
        baseColor1.rgb = srgbToLinear(hslToSrgb(baseColor1.xyz));
        baseColor2.rgb = srgbToLinear(hslToSrgb(baseColor2.xyz));
        baseColor3.rgb = srgbToLinear(hslToSrgb(baseColor3.xyz));

        #if DISPLAY_BASE_COLOR
        if (DISPLAY_BASE_COLOR == 1) { // Redundant, used for syntax highlighting in IntelliJ
            outputColor = baseColor1 * IN.texBlend.x + baseColor2 * IN.texBlend.y + baseColor3 * IN.texBlend.z;
            outputColor.rgb = linearToSrgb(outputColor.rgb);
            FragColor = outputColor;
            return;
        }
        #endif

        // get diffuse textures
        vec4 texColor1 = colorMap1 == -1 ? vec4(1) : texture(textureArray, vec3(uv1, colorMap1), mipBias);
        vec4 texColor2 = colorMap2 == -1 ? vec4(1) : texture(textureArray, vec3(uv2, colorMap2), mipBias);
        vec4 texColor3 = colorMap3 == -1 ? vec4(1) : texture(textureArray, vec3(uv3, colorMap3), mipBias);
        texColor1.rgb *= material1.brightness;
        texColor2.rgb *= material2.brightness;
        texColor3.rgb *= material3.brightness;

        ivec3 isOverlay = ivec3(
            fMaterialData[0] >> MATERIAL_FLAG_IS_OVERLAY & 1,
            fMaterialData[1] >> MATERIAL_FLAG_IS_OVERLAY & 1,
            fMaterialData[2] >> MATERIAL_FLAG_IS_OVERLAY & 1
        );
        int overlayCount = isOverlay[0] + isOverlay[1] + isOverlay[2];
        ivec3 isUnderlay = ivec3(1) - isOverlay;
        int underlayCount = isUnderlay[0] + isUnderlay[1] + isUnderlay[2];

        // calculate blend amounts for overlay and underlay vertices
        vec3 underlayBlend = IN.texBlend * isUnderlay;
        vec3 overlayBlend = IN.texBlend * isOverlay;

        if (underlayCount == 0 || overlayCount == 0)
        {
            // if a tile has all overlay or underlay vertices,
            // use the default blend

            underlayBlend = IN.texBlend;
            overlayBlend = IN.texBlend;
        }
        else
        {
            // if there's a mix of overlay and underlay vertices,
            // calculate custom blends for each 'layer'

            float underlayBlendMultiplier = 1.0 / (underlayBlend[0] + underlayBlend[1] + underlayBlend[2]);
            // adjust back to 1.0 total
            underlayBlend *= underlayBlendMultiplier;
            underlayBlend = clamp(underlayBlend, 0, 1);

            float overlayBlendMultiplier = 1.0 / (overlayBlend[0] + overlayBlend[1] + overlayBlend[2]);
            // adjust back to 1.0 total
            overlayBlend *= overlayBlendMultiplier;
            overlayBlend = clamp(overlayBlend, 0, 1);
        }


        // get fragment colors by combining vertex colors and texture samples
        vec4 texA = getMaterialShouldOverrideBaseColor(material1) ? texColor1 : vec4(texColor1.rgb * baseColor1.rgb, min(texColor1.a, baseColor1.a));
        vec4 texB = getMaterialShouldOverrideBaseColor(material2) ? texColor2 : vec4(texColor2.rgb * baseColor2.rgb, min(texColor2.a, baseColor2.a));
        vec4 texC = getMaterialShouldOverrideBaseColor(material3) ? texColor3 : vec4(texColor3.rgb * baseColor3.rgb, min(texColor3.a, baseColor3.a));

        // combine fragment colors based on each blend, creating
        // one color for each overlay/underlay 'layer'
        vec4 underlayColor = texA * underlayBlend.x + texB * underlayBlend.y + texC * underlayBlend.z;
        vec4 overlayColor = texA * overlayBlend.x + texB * overlayBlend.y + texC * overlayBlend.z;

        float overlayMix = 0;

        if (overlayCount > 0 && underlayCount > 0)
        {
            ivec3 isPrimary = isUnderlay;
            bool invert = true;
            if (overlayCount == 1) {
                isPrimary = isOverlay;
                invert = false;
            }

            float result = dot(IN.texBlend, isPrimary);
            if (invert)
                result = 1 - result;

            result = clamp(result * 2 - 1, 0, 1);
            overlayMix = result;

				// Keep 117's proven cross-tile interpolation authoritative.  The former
				// 0.16 noise offset was strong enough to expose triangular/square patches.
				// A very small continuous perturbation only softens perfectly straight seams.
				if (auroraEnabled != 0 && isTerrain) {
					float boundaryNoise = auroraFbm(auroraDetailXz() / 260.0) - 0.5;
					overlayMix = smoothstep(0.08, 0.92,
						clamp(overlayMix + boundaryNoise * 0.04 * auroraTerrainDetail, 0.0, 1.0));
				}
        }

        outputColor = mix(underlayColor, overlayColor, overlayMix);

        // Aurora 0.55.5 Winter blend: the inherited winter material system remains
        // authoritative, but Aurora snow reduces visible per-tile color steps using a
        // continuous world-space frost tone. This does not alter non-snow terrain.
        if (auroraEnabled != 0 && isTerrain && !isUnderwater) {
            float snowBlend = dot(IN.texBlend, vec3(
                auroraSnowMaterial(material1), auroraSnowMaterial(material2), auroraSnowMaterial(material3)));
            if (snowBlend > 0.001) {
                vec2 snowWorld = auroraDetailXz();
                float snowMacro = auroraFbm(snowWorld / 360.0);
                float snowFine = auroraFbm(snowWorld / 92.0 + vec2(19.0, -7.0));
                float frost = clamp(snowMacro * 0.72 + snowFine * 0.28, 0.0, 1.0);
                vec3 snowTone = mix(vec3(0.79, 0.86, 0.90), vec3(0.93, 0.96, 0.97), frost);
                float snowCrystal = auroraNoise(snowWorld / 11.0 + vec2(47.0, -23.0)) - 0.5;
                float snowSpark = smoothstep(0.925, 0.992, auroraNoise(snowWorld / 5.5 + vec2(-11.0, 61.0)));
                snowTone *= 1.0 + snowCrystal * 0.035 + snowSpark * 0.028;
                float authoredLuma = dot(outputColor.rgb, vec3(0.2126, 0.7152, 0.0722));
                snowTone *= mix(0.94, 1.045, clamp(authoredLuma, 0.0, 1.0));
                outputColor.rgb = mix(outputColor.rgb, snowTone, snowBlend * 0.52);
            }
        }

	        // Aurora 0.16 Materials 2.0: restrained multi-scale albedo variation breaks up
	        // large uniform terrain patches without replacing authored material textures.
	        if (auroraEnabled != 0 && auroraMaterialResponse != 0 && isTerrain && !isUnderwater) {
	            vec2 detailWorld = auroraDetailXz();
	            float macroTone = auroraFbm(detailWorld / 310.0) - 0.5;
	            float microTone = auroraNoise(detailWorld / 34.0) - 0.5;
	            float variation = macroTone * 0.055 * auroraMaterialDepth + microTone * 0.014 * auroraTerrainDetail;
	            outputColor.rgb *= 1.0 + variation;
	            // Wet surfaces absorb more diffuse light; specular is handled below.
            outputColor.rgb *= mix(1.0, 0.68, clamp(auroraWetness, 0.0, 1.0));
        }

        // normals
        vec3 normals;
        if ((fMaterialData[0] >> MATERIAL_FLAG_UPWARDS_NORMALS & 1) == 1) {
            normals = vec3(0, -1, 0);
        } else {
            vec3 n1 = sampleNormalMap(material1, uv1, TBN);
            vec3 n2 = sampleNormalMap(material2, uv2, TBN);
            vec3 n3 = sampleNormalMap(material3, uv3, TBN);
            normals = normalize(n1 * IN.texBlend.x + n2 * IN.texBlend.y + n3 * IN.texBlend.z);
        }

			// Add fine world-space surface response even when the source material lacks a normal map.
			if (auroraEnabled != 0 && auroraMaterialResponse != 0 && isTerrain && !isUnderwater) {
				vec2 detailWorld = auroraDetailXz();
				vec2 p = detailWorld / 42.0;
				float center = auroraNoise(p);
				vec2 gradient = vec2(auroraNoise(p + vec2(0.08, 0.0)) - center,
					auroraNoise(p + vec2(0.0, 0.08)) - center);
				vec2 coarseP = detailWorld / 118.0;
				float coarseCenter = auroraFbm(coarseP);
			vec2 coarseGradient = vec2(auroraFbm(coarseP + vec2(0.06, 0.0)) - coarseCenter,
				auroraFbm(coarseP + vec2(0.0, 0.06)) - coarseCenter);
			normals.xz += gradient * (0.9 * auroraTerrainDetail);
			normals.xz += coarseGradient * (1.6 * auroraMaterialDepth);
			normals = normalize(normals);
		}

        if (auroraEnabled != 0 && auroraMaterialResponse != 0 && !isTerrain && !isWater && !isUnderwater) {
            float barkDetail = dot(IN.texBlend, vec3(
                auroraBarkMaterial(material1), auroraBarkMaterial(material2), auroraBarkMaterial(material3)));
            float woodDetail = dot(IN.texBlend, vec3(
                auroraPropWoodMaterial(material1), auroraPropWoodMaterial(material2), auroraPropWoodMaterial(material3)));
            float hayDetail = dot(IN.texBlend, vec3(
                auroraHayMaterial(material1), auroraHayMaterial(material2), auroraHayMaterial(material3)));
            float rockDetail = dot(IN.texBlend, vec3(
                auroraRockMaterial(material1), auroraRockMaterial(material2), auroraRockMaterial(material3)));
            float stoneDetail = dot(IN.texBlend, vec3(
                auroraStoneLikeMaterial(material1), auroraStoneLikeMaterial(material2), auroraStoneLikeMaterial(material3)));
            float metalDetail = dot(IN.texBlend, vec3(
                auroraMetalMaterial(material1), auroraMetalMaterial(material2), auroraMetalMaterial(material3)));
            float foliageDetail = dot(IN.texBlend, vec3(
                auroraFoliageMaterial(material1), auroraFoliageMaterial(material2), auroraFoliageMaterial(material3)));
            float classDetail = clamp(
                barkDetail * 0.70 +
                woodDetail * 0.42 +
                hayDetail * 0.34 +
                rockDetail * 0.62 +
                stoneDetail * 0.46 +
                metalDetail * 0.24 +
                foliageDetail * 0.18, 0.0, 1.0);

            float organicFineDetail = clamp(barkDetail + hayDetail, 0.0, 1.0);
	            vec2 detailP = auroraDetailXz() / mix(34.0, 19.0, organicFineDetail);
            float detailCenter = auroraFbm(detailP);
            vec2 detailGradient = vec2(
                auroraFbm(detailP + vec2(0.045, 0.0)) - detailCenter,
                auroraFbm(detailP + vec2(0.0, 0.045)) - detailCenter);
            normals.xz += detailGradient * (1.35 * auroraMaterialDepth * classDetail);
            normals = normalize(normals);
        }

        float lightDotNormals = dot(normals, lightDir);
        float downDotNormals = dot(downDir, normals);
        float viewDotNormals = dot(viewDir, normals);

        #if DISABLE_DIRECTIONAL_SHADING
            lightDotNormals = .7;
        #endif

        float shadow = 0;
        if ((fMaterialData[0] >> MATERIAL_FLAG_DISABLE_SHADOW_RECEIVING & 1) == 0)
            shadow = sampleShadowMap(fragPos, vec2(0), lightDotNormals);
        shadow = max(shadow, selfShadowing);
        if (auroraEnabled != 0) {
            // Lighting 2.0: retain crisp nearby contact shadows while gently
            // broadening the partially-filtered edge farther from the camera.
            // Fully-lit and fully-shadowed texels are left alone, so this costs no
            // extra shadow-map taps and does not turn distant shadows grey.
            float shadowDistance = length(fragPos.xz - cameraPos.xz) / max(drawDistance * 128.0, 128.0);
            float farSoftness = smoothstep(0.46, 0.92, shadowDistance);
            float edgeWeight = clamp(4.0 * shadow * (1.0 - shadow), 0.0, 1.0);
            shadow = mix(shadow, 0.5, edgeWeight * farSoftness * 0.20);
        }
        float inverseShadow = 1 - shadow;

        #if DISPLAY_SHADOWS
            FragColor = vec4(inverseShadow, inverseShadow, inverseShadow, 1.0);
            if (DISPLAY_SHADOWS == 1) return; // Redundant, for syntax highlighting in IntelliJ
        #endif

        // specular
        vec3 vSpecularGloss = vec3(material1.specularGloss, material2.specularGloss, material3.specularGloss);
        vec3 vSpecularStrength = vec3(material1.specularStrength, material2.specularStrength, material3.specularStrength);
        vSpecularStrength *= vec3(
            material1.roughnessMap == -1 ? 1 : linearToSrgb(texture(textureArray, vec3(uv1, material1.roughnessMap)).r),
            material2.roughnessMap == -1 ? 1 : linearToSrgb(texture(textureArray, vec3(uv2, material2.roughnessMap)).r),
            material3.roughnessMap == -1 ? 1 : linearToSrgb(texture(textureArray, vec3(uv3, material3.roughnessMap)).r)
        );
			if (auroraEnabled != 0 && !isUnderwater) {
				float roughVariation = auroraNoise(auroraDetailXz() / 58.0);
			float wettable = isTerrain ? 1.0 : dot(IN.texBlend, vec3(
				auroraWettableMaterial(material1), auroraWettableMaterial(material2), auroraWettableMaterial(material3)));
			vSpecularStrength *= mix(vec3(1.0), vec3(0.68 + roughVariation * 0.28), auroraTerrainDetail * wettable);
			vSpecularGloss *= mix(vec3(1.0), vec3(0.82 + roughVariation * 0.20), auroraTerrainDetail * wettable);
            float wet = clamp(auroraWetness, 0.0, 1.0);
            // Materials 3.0: use the authored/base specular response as a conservative
            // proxy for material class. Stone/rock respond strongly; dull grass/dirt less so.
            float baseSpecular = max(vSpecularStrength.x, max(vSpecularStrength.y, vSpecularStrength.z));
            float materialWetResponse = clamp(0.28 + baseSpecular * 2.1, 0.28, 1.0);
            float effectiveWet = wet * materialWetResponse * wettable;
            vSpecularStrength *= mix(vec3(1.0), vec3(2.35), effectiveWet);
            vSpecularGloss *= mix(vec3(1.0), vec3(1.85), effectiveWet);
		}
        if (auroraEnabled != 0 && auroraMaterialResponse != 0 && !isTerrain && !isWater && !isUnderwater) {
            float materialWood = dot(IN.texBlend, vec3(
                auroraBarkMaterial(material1) + auroraPropWoodMaterial(material1),
                auroraBarkMaterial(material2) + auroraPropWoodMaterial(material2),
                auroraBarkMaterial(material3) + auroraPropWoodMaterial(material3)));
            float materialStone = dot(IN.texBlend, vec3(
                auroraRockMaterial(material1) + auroraStoneLikeMaterial(material1),
                auroraRockMaterial(material2) + auroraStoneLikeMaterial(material2),
                auroraRockMaterial(material3) + auroraStoneLikeMaterial(material3)));
            float materialMetal = dot(IN.texBlend, vec3(
                auroraMetalMaterial(material1), auroraMetalMaterial(material2), auroraMetalMaterial(material3)));
            float materialHay = dot(IN.texBlend, vec3(
                auroraHayMaterial(material1), auroraHayMaterial(material2), auroraHayMaterial(material3)));
            float materialFoliage = dot(IN.texBlend, vec3(
                auroraFoliageMaterial(material1), auroraFoliageMaterial(material2), auroraFoliageMaterial(material3)));
            float materialRoof = dot(IN.texBlend, vec3(
                auroraRoofMaterial(material1), auroraRoofMaterial(material2), auroraRoofMaterial(material3)));
            float materialIronBars = dot(IN.texBlend, vec3(
                auroraIronBarsMaterial(material1), auroraIronBarsMaterial(material2), auroraIronBarsMaterial(material3)));

            float dullOrganic = clamp(materialWood * 0.75 + materialHay + materialFoliage * 0.55, 0.0, 1.0);
            float hardSurface = clamp(materialStone * 0.65 + materialMetal + materialRoof * 0.38, 0.0, 1.0);
            vSpecularStrength *= mix(vec3(1.0), vec3(0.68), dullOrganic * auroraMaterialDepth);
            vSpecularGloss *= mix(vec3(1.0), vec3(0.78), dullOrganic * auroraMaterialDepth);
            vSpecularStrength *= mix(vec3(1.0), vec3(1.22), hardSurface * auroraMaterialDepth);
            vSpecularGloss *= mix(vec3(1.0), vec3(1.12), hardSurface * auroraMaterialDepth);
            // Thin iron/metal structures catch narrower highlights than broad masonry.
            vSpecularStrength *= mix(vec3(1.0), vec3(1.18), materialIronBars * auroraMaterialDepth);
            vSpecularGloss *= mix(vec3(1.0), vec3(1.24), materialIronBars * auroraMaterialDepth);
        }

        // apply specular highlights to anything semi-transparent
        // this isn't always desirable but adds subtle light reflections to windows, etc.
        if (baseColor1.a + baseColor2.a + baseColor3.a < 2.99)
        {
            vSpecularGloss = vec3(30);
            vSpecularStrength = vec3(
                clamp((1 - baseColor1.a) * 2, 0, 1),
                clamp((1 - baseColor2.a) * 2, 0, 1),
                clamp((1 - baseColor3.a) * 2, 0, 1)
            );
        }
        float combinedSpecularStrength = dot(vSpecularStrength, IN.texBlend);


        // calculate lighting

        // ambient light
        vec3 ambientLightOut = ambientColor * ambientStrength;
		float auroraClock = auroraTime();
		float auroraSunHeight = sin((auroraClock - 0.25) * 6.28318530718);
		float auroraDaylight = smoothstep(-0.18, 0.12, auroraSunHeight);
		if (auroraEnabled != 0 && auroraSkyEnabled != 0) {
            float twilightFill = exp(-pow(abs(auroraSunHeight) * 3.55, 2.0));
            vec3 nightAmbient = vec3(0.58, 0.70, 1.00);
            vec3 dayAmbient = mix(vec3(1.00, 0.985, 0.95), vec3(1.04, 0.94, 0.86), twilightFill * 0.20);
			ambientLightOut *= mix(nightAmbient, dayAmbient, auroraDaylight);
            ambientLightOut += mix(vec3(0.055, 0.075, 0.13), vec3(0.12, 0.075, 0.050), auroraDaylight)
                * twilightFill * 0.20;
		}

        float aoFactor =
            IN.texBlend.x * (material1.ambientOcclusionMap == -1 ? 1 : texture(textureArray, vec3(uv1, material1.ambientOcclusionMap)).r) +
            IN.texBlend.y * (material2.ambientOcclusionMap == -1 ? 1 : texture(textureArray, vec3(uv2, material2.ambientOcclusionMap)).r) +
            IN.texBlend.z * (material3.ambientOcclusionMap == -1 ? 1 : texture(textureArray, vec3(uv3, material3.ambientOcclusionMap)).r);
        ambientLightOut *= aoFactor;

        // directional light
        vec3 dirLightColor = lightColor * lightStrength;

		// Lighting 2.0: the celestial clock now controls both hue and perceived
        // intensity. Low sun is distinctly warm; moonlight stays cool and restrained.
		if (auroraEnabled != 0 && auroraSkyEnabled != 0) {
			float goldenHour = exp(-pow(abs(auroraSunHeight) * 3.15, 2.0));
            float highSun = smoothstep(0.18, 0.72, auroraSunHeight);
			vec3 moonTint = vec3(0.34, 0.48, 0.82);
            vec3 sunriseTint = vec3(1.24, 0.66, 0.34);
            vec3 noonTint = vec3(1.04, 1.00, 0.93);
			vec3 dayTint = mix(sunriseTint, noonTint, highSun);
            dayTint = mix(dayTint, sunriseTint, goldenHour * 0.18);
            float celestialStrength = mix(0.48, 1.16, auroraDaylight);
			dirLightColor *= mix(moonTint, dayTint, auroraDaylight) * celestialStrength;
		}

		// The same coherent weather field also drives water and surface response.
		if (auroraEnabled != 0 && auroraWeatherEnabled != 0 && auroraCloudShadows > 0.0) {
            float auroraSnowSurface = dot(IN.texBlend, vec3(
                auroraSnowMaterial(material1), auroraSnowMaterial(material2), auroraSnowMaterial(material3)));
			float cloud = auroraCloudField(auroraWorldXz());
			float penumbra = smoothstep(0.045, 0.72, cloud);
            float shadowStrength = mix(0.78, 0.92, 1.0 - auroraWetness * 0.30);
            // 0.55.5: cloud shadows are intentionally ~60% darker than 0.55.4.
            float cloudDarkening = clamp(penumbra * shadowStrength * auroraCloudShadows * 1.60, 0.0, 0.97);
			dirLightColor *= 1.0 - cloudDarkening;
            // Snow's bright ambient used to wash out Winter shade. Preserve the
            // 60%-darker cloud shadows and also trim ambient only on snow surfaces.
            ambientLightOut *= 1.0 - cloudDarkening * 0.24 * auroraSnowSurface;
		}

        // underwater caustics based on directional light
        if (underwaterCaustics && underwaterEnvironment) {
            float scale = 12.8;
            vec2 causticsUv = worldUvs(scale);

            const ivec2 direction = ivec2(1, -1);
            const int driftSpeed = 231;
            vec2 drift = animationFrame(231) * ivec2(1, -2);
            vec2 flow1 = causticsUv + animationFrame(19) * direction + drift;
            vec2 flow2 = causticsUv * 1.25 + animationFrame(37) * -direction + drift;

            vec3 caustics = sampleCaustics(flow1, flow2) * 2;

            vec3 causticsColor = underwaterCausticsColor * underwaterCausticsStrength;
            dirLightColor += caustics * causticsColor * lightDotNormals * pow(lightStrength, 1.5);
        }

        // apply shadows
        dirLightColor *= inverseShadow;
        if (auroraEnabled != 0) {
            float auroraSnowSurfaceShadow = dot(IN.texBlend, vec3(
                auroraSnowMaterial(material1), auroraSnowMaterial(material2), auroraSnowMaterial(material3)));
            // Winter snow keeps enough ambient to remain readable, but direct
            // shadows now retain visibly more shape instead of washing to flat white.
            ambientLightOut *= 1.0 - (1.0 - inverseShadow) * auroraSnowSurfaceShadow * 0.30;
        }

        vec3 lightColor = dirLightColor;
        vec3 lightOut = max(lightDotNormals, 0.0) * lightColor;

        // directional light specular
        vec3 lightReflectDir = reflect(-lightDir, normals);
        vec3 lightSpecularOut = lightColor * specular(IN.texBlend, viewDir, lightReflectDir, vSpecularGloss, vSpecularStrength);

        // point lights
        vec3 pointLightsOut = vec3(0);
        vec3 pointLightsSpecularOut = vec3(0);
        calculateLighting(IN.position, normals, viewDir, IN.texBlend, vSpecularGloss, vSpecularStrength, pointLightsOut, pointLightsSpecularOut);
        if (auroraEnabled != 0) {
            // Local emissive lights already provide direct diffuse/specular through
            // 117's light system. Add a restrained diffuse bounce so fires, torches
            // and lava read as light sources instead of isolated bright points.
            float localLightEnergy = clamp(max(max(pointLightsOut.r, pointLightsOut.g), pointLightsOut.b), 0.0, 2.0);
            pointLightsOut += pointLightsOut * (0.055 + 0.045 * smoothstep(0.08, 1.10, localLightEnergy)) * aoFactor;
        }

        // sky light
        vec3 skyLightColor = fogColor;
        float skyLightStrength = 0.5;
        float skyDotNormals = downDotNormals;
        vec3 skyLightOut = max(skyDotNormals, 0.0) * skyLightColor * skyLightStrength;

        // Aurora 0.55 Lighting/Shadows 2.0: a shadow should remove direct sun, not
        // all environmental illumination.  Add a restrained sky/ground bounce term
        // that is strongest on upward-facing geometry and in deep directional shadow.
        // AO still suppresses the fill in creases, preserving contact and depth.
        if (auroraEnabled != 0 && auroraSkyEnabled != 0) {
            float skyFacing = clamp(downDotNormals, 0.0, 1.0);
            float directionalShadow = clamp(shadow, 0.0, 1.0);
            vec3 nightBounce = vec3(0.035, 0.045, 0.072);
            vec3 dayBounce = mix(vec3(0.045, 0.052, 0.060), vec3(0.072, 0.064, 0.052),
                exp(-pow(abs(auroraSunHeight) * 3.2, 2.0)));
            vec3 celestialBounce = mix(nightBounce, dayBounce, auroraDaylight);
            float bounceStrength = (0.20 + directionalShadow * 0.44) * skyFacing * aoFactor;
            skyLightOut += celestialBounce * bounceStrength;
        }


        // lightning
        vec3 lightningColor = vec3(.25, .25, .25);
        float lightningStrength = lightningBrightness;
        float lightningDotNormals = downDotNormals;
        vec3 lightningOut = max(lightningDotNormals, 0.0) * lightningColor * lightningStrength;


        // underglow
        vec3 underglowOut = underglowColor * max(normals.y, 0) * underglowStrength;


        // fresnel reflection
        float baseOpacity = 0.4;
        float fresnel = 1.0 - clamp(viewDotNormals, 0.0, 1.0);
        float finalFresnel = clamp(mix(baseOpacity, 1.0, fresnel * 1.2), 0.0, 1.0);
        vec3 surfaceColor = vec3(0);
        vec3 surfaceColorOut = surfaceColor * max(combinedSpecularStrength, 0.2);


        // apply lighting
        vec3 compositeLight = ambientLightOut + lightOut + lightSpecularOut + skyLightOut + lightningOut +
        underglowOut + pointLightsOut + pointLightsSpecularOut + surfaceColorOut;

        #if DISPLAY_LIGHTING
            FragColor = vec4(compositeLight, 1.0);
            if (DISPLAY_LIGHTING == 1) return; // Redundant, for syntax highlighting in IntelliJ
        #endif

        float unlit = dot(IN.texBlend, vec3(
            getMaterialIsUnlit(material1),
            getMaterialIsUnlit(material2),
            getMaterialIsUnlit(material3)
        ));

        #if VANILLA_COLOR_BANDING
            outputColor.rgb = linearToSrgb(outputColor.rgb);
            outputColor.rgb = srgbToHsv(outputColor.rgb);
            outputColor.b = floor(outputColor.b * 127) / 127;
            outputColor.rgb = hsvToSrgb(outputColor.rgb);
            outputColor.rgb = srgbToLinear(outputColor.rgb);
        #endif

        if (tint.w > 0) {
            outputColor.rgb *= 1.0 + skyLightOut;
        } else {
            outputColor.rgb *= mix(compositeLight, vec3(1), unlit);
        }

        // World Surface Overhaul: retain Aurora's large cloud-shadow shapes, but
        // stop healthy terrain from collapsing to near-black beneath them.  This
        // is deliberately applied before gamma so the lift preserves hue/detail
        // instead of putting a grey veil over the scene.
        if (auroraEnabled != 0 && auroraMaterialResponse != 0 && isTerrain && !isUnderwater) {
            float cloudShadow = 0.0;
            if (auroraWeatherEnabled != 0 && auroraCloudShadows > 0.0) {
                cloudShadow = smoothstep(0.18, 0.92, auroraCloudField(auroraWorldXz())) * auroraCloudShadows;
            }
            float retainedLight = mix(0.0, 0.020, cloudShadow) * (0.65 + 0.35 * auroraTerrainDetail);
            outputColor.rgb += outputColor.rgb * retainedLight;
        }
        outputColor.rgb = linearToSrgb(outputColor.rgb);

        if (isUnderwater) {
            sampleUnderwater(outputColor.rgb, waterType, waterDepth, lightDotNormals);
        }
    }

    #if LEGACY_RENDERER
        vec2 tiledist = abs(floor(IN.position.xz / 128) - floor(cameraPos.xz / 128));
        float maxDist = max(tiledist.x, tiledist.y);
        if (maxDist > drawDistance) {
            // Rapidly fade out any geometry that extends beyond the draw distance.
            // This is required if we always draw all underwater terrain.
            outputColor.a *= -256;
        }
    #endif

    // Aurora 0.24 canopy identity: preserve original/seasonal leaf artwork while
    // making ordinary LEAF_VEINS trees and the vanilla leaf sheets visibly distinct.
    if (auroraEnabled != 0 && auroraMaterialResponse != 0 && !isTerrain && !isWater && !isUnderwater) {
        float broadleaf = dot(IN.texBlend, vec3(
            auroraBroadleafMaterial(material1), auroraBroadleafMaterial(material2), auroraBroadleafMaterial(material3)));
        float willow = dot(IN.texBlend, vec3(
            auroraWillowMaterial(material1), auroraWillowMaterial(material2), auroraWillowMaterial(material3)));
        float evergreen = dot(IN.texBlend, vec3(
            auroraEvergreenMaterial(material1), auroraEvergreenMaterial(material2), auroraEvergreenMaterial(material3)));
        float yew = dot(IN.texBlend, vec3(
            auroraYewMaterial(material1), auroraYewMaterial(material2), auroraYewMaterial(material3)));
        float yewSeason = dot(IN.texBlend, vec3(
            auroraYewSeasonMaterial(material1), auroraYewSeasonMaterial(material2), auroraYewSeasonMaterial(material3)));
        float oak = dot(IN.texBlend, vec3(
            auroraOakMaterial(material1), auroraOakMaterial(material2), auroraOakMaterial(material3)));
        float smallTree = dot(IN.texBlend, vec3(
            auroraSmallTreeMaterial(material1), auroraSmallTreeMaterial(material2), auroraSmallTreeMaterial(material3)));
        float maple = dot(IN.texBlend, vec3(
            auroraMapleMaterial(material1), auroraMapleMaterial(material2), auroraMapleMaterial(material3)));
        float magicLeaves = dot(IN.texBlend, vec3(
            auroraMagicLeavesMaterial(material1), auroraMagicLeavesMaterial(material2), auroraMagicLeavesMaterial(material3)));
        float hedge = dot(IN.texBlend, vec3(
            auroraHedgeMaterial(material1), auroraHedgeMaterial(material2), auroraHedgeMaterial(material3)));
        float bark = dot(IN.texBlend, vec3(
            auroraBarkMaterial(material1), auroraBarkMaterial(material2), auroraBarkMaterial(material3)));
        float magic = dot(IN.texBlend, vec3(
            auroraMagicMaterial(material1), auroraMagicMaterial(material2), auroraMagicMaterial(material3)));
	        float foliage = dot(IN.texBlend, vec3(
	            auroraFoliageMaterial(material1), auroraFoliageMaterial(material2), auroraFoliageMaterial(material3)));
	        float topFacing = clamp(-normalize(IN.normal).y, 0.0, 1.0);
	        vec2 objectWorld = auroraDetailXz();
	        float instanceSeed = auroraNoise(floor(objectWorld / 96.0) * 2.37 + vec2(17.0, -41.0));
	        float materialSeed = auroraFbm(floor(objectWorld / 128.0) * 1.83 + vec2(31.0, -12.0)) - 0.5;
        if (auroraEnabled != 0 && auroraMaterialResponse != 0) {
            float objectMaterial = clamp(
                foliage + bark +
                auroraPropWoodMaterial(material1) * IN.texBlend.x +
                auroraPropWoodMaterial(material2) * IN.texBlend.y +
                auroraPropWoodMaterial(material3) * IN.texBlend.z +
                auroraRockMaterial(material1) * IN.texBlend.x +
                auroraRockMaterial(material2) * IN.texBlend.y +
                auroraRockMaterial(material3) * IN.texBlend.z +
                auroraStoneLikeMaterial(material1) * IN.texBlend.x +
                auroraStoneLikeMaterial(material2) * IN.texBlend.y +
                auroraStoneLikeMaterial(material3) * IN.texBlend.z, 0.0, 1.0);
            outputColor.rgb *= 1.0 + materialSeed * 0.055 * objectMaterial * auroraMaterialDepth;
        }
	        float canopyClosure = smoothstep(0.46, 0.78, topFacing) *
	            smoothstep(0.40, 0.74, auroraFbm(objectWorld / 145.0 + vec2(7.0, -19.0)));
	        float grove = auroraFbm(floor(objectWorld / 320.0) * 1.73 + vec2(11.2, -4.8));
        float lightVariant = smoothstep(0.54, 0.78, grove);
        vec3 deepLeaf = vec3(0.69, 0.88, 0.64);
        vec3 lightLeaf = vec3(0.95, 1.22, 0.78);
        vec3 leafInstanceTone = mix(vec3(0.94, 1.04, 0.96), vec3(1.04, 0.98, 0.90), instanceSeed);
        vec3 canopyTint = mix(deepLeaf, lightLeaf, lightVariant * 0.72 + topFacing * 0.28) * leafInstanceTone;
        float canopyStrength = broadleaf * mix(0.10, 0.20, lightVariant) * mix(0.82, 1.18, instanceSeed);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * canopyTint, canopyStrength);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * vec3(0.78, 0.96, 0.70),
            broadleaf * canopyClosure * 0.22);

        // Strengthen the dark grooves already present in the artwork without
        // replacing alpha, UVs, per-species colors or any seasonal material.
        float canopyLuma = dot(outputColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        float interiorInk = (1.0 - smoothstep(0.12, 0.52, canopyLuma)) * (0.72 + 0.28 * (1.0 - topFacing));
        outputColor.rgb *= mix(1.0, 0.82, broadleaf * interiorInk * 0.35);
        outputColor.a = mix(outputColor.a, max(outputColor.a, 0.72),
            broadleaf * canopyClosure * smoothstep(0.14, 0.44, outputColor.a) * 0.22);

	        // Willows should read as heavier, draped and darker than ordinary leaves.
	        vec3 willowTint = mix(vec3(0.58, 0.72, 0.48), vec3(0.82, 0.94, 0.64), topFacing);
	        float willowDrape = smoothstep(0.18, 0.72, auroraFbm(objectWorld / 90.0 + vec2(-12.0, 31.0)));
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * willowTint,
            willow * mix(0.26, 0.42, willowDrape));

        // Evergreen/yew-style reads should stay darker, cooler and denser than
        // ordinary leaf clumps. This is intentionally a tint/response layer so
	        // the underlying OSRS silhouettes and seasonal paths survive.
	        vec3 evergreenTint = mix(vec3(0.42, 0.62, 0.42), vec3(0.56, 0.78, 0.48), topFacing);
	        float needleNoise = auroraFbm(objectWorld / 58.0 + vec2(23.0, 5.0));
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * evergreenTint,
            evergreen * mix(0.24, 0.40, needleNoise));

	        vec3 yewTint = mix(vec3(0.32, 0.48, 0.39), vec3(0.44, 0.64, 0.50), topFacing);
	        float yewNeedle = auroraNoise(objectWorld / 21.0 + vec2(17.0, -33.0));
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * yewTint * mix(0.88, 1.04, yewNeedle),
            yew * (1.0 - yewSeason) * 0.72);

	        vec3 mapleGreen = mix(vec3(0.48, 0.68, 0.36), vec3(0.82, 0.98, 0.56), topFacing);
	        vec3 mapleTint = mix(mapleGreen, vec3(0.74, 0.48, 0.28), 0.15 * (1.0 - topFacing));
	        float mapleMottle = auroraFbm(objectWorld / 52.0 + vec2(-8.0, 14.0));
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * vec3(0.72, 0.91, 0.67),
            oak * mix(0.30, 0.46, canopyClosure));

        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * vec3(0.88, 1.05, 0.73),
            smallTree * mix(0.22, 0.36, lightVariant));

        float mapleSummer = dot(IN.texBlend, vec3(
            auroraMapMatch(material1, MAT_AURORA_MAPLE_SUMMER.colorMap),
            auroraMapMatch(material2, MAT_AURORA_MAPLE_SUMMER.colorMap),
            auroraMapMatch(material3, MAT_AURORA_MAPLE_SUMMER.colorMap)));
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * mapleTint,
            maple * (1.0 - mapleSummer) * mix(0.50, 0.67, mapleMottle));

	        vec3 hedgeTint = mix(vec3(0.36, 0.56, 0.30), vec3(0.50, 0.68, 0.34), topFacing);
	        float clippedLeaf = smoothstep(0.24, 0.72, auroraNoise(floor(objectWorld / 9.0)));
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * hedgeTint * mix(0.82, 1.08, clippedLeaf),
            hedge * 0.66);

	        vec3 magicLeafTint = mix(vec3(0.46, 0.62, 0.82), vec3(0.62, 0.48, 0.98), topFacing);
	        float magicLeafPulse = 0.5 + 0.5 * sin(elapsedTime * 1.2 + auroraNoise(objectWorld / 12.0) * 10.0);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * magicLeafTint + vec3(0.02, 0.04, 0.08) * magicLeafPulse,
            magicLeaves * 0.58);

	        // Magic-tree sparkle identity: subtle color pulse on the star material,
	        // not a full particle system yet.
	        float sparkle = 0.5 + 0.5 * sin(elapsedTime * 2.2 + auroraNoise(objectWorld / 9.0) * 18.0);
        vec3 magicGlow = mix(vec3(0.62, 0.42, 1.25), vec3(0.38, 0.92, 1.18), sparkle);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * magicGlow + magicGlow * 0.10,
            magic * 0.58);

        if (auroraEnabled != 0 && auroraMaterialResponse != 0) {
	            float backface = gl_FrontFacing ? 0.0 : 1.0;
	            float alphaWindow = smoothstep(0.012, 0.36, outputColor.a) *
	                (1.0 - smoothstep(0.82, 0.995, outputColor.a));
	            float fillField = smoothstep(0.24, 0.72,
	                auroraFbm(objectWorld / 38.0 + vec2(5.7, -14.2)));
            float leafFill = foliage * alphaWindow * fillField *
                (0.20 + topFacing * 0.17 + backface * 0.14);
            outputColor.a = mix(outputColor.a, max(outputColor.a, 0.62 + topFacing * 0.20), leafFill);
            outputColor.rgb *= mix(vec3(1.0), vec3(0.88, 0.96, 0.82),
                foliage * backface * 0.10);
        }

        // Bark depth: dark vertical fissures and warmer raised ridges.
        float barkColumn = auroraFbm(vec2(IN.position.x * 0.012, IN.position.y * 0.034) + 41.0);
        float barkFine = auroraNoise(vec2(IN.position.z * 0.024, IN.position.y * 0.082) + 9.0);
        float barkGroove = smoothstep(0.30, 0.76, barkColumn);
        float barkRidge = smoothstep(0.55, 0.94, barkFine);
        vec3 barkTone = mix(vec3(0.46, 0.32, 0.22), vec3(1.18, 0.92, 0.62), barkGroove * 0.72 + barkRidge * 0.28);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * barkTone,
            bark * 0.64);

        float objectWettable = dot(IN.texBlend, vec3(
            auroraWettableMaterial(material1), auroraWettableMaterial(material2), auroraWettableMaterial(material3)));
        outputColor.rgb *= mix(1.0, 0.76, auroraWetness * objectWettable);

	        float propWood = dot(IN.texBlend, vec3(
	            auroraPropWoodMaterial(material1), auroraPropWoodMaterial(material2), auroraPropWoodMaterial(material3)));
	        float propGrain = auroraFbm(objectWorld / 48.0 + vec2(5.0, 29.0)) - 0.5;
        vec3 propTone = mix(vec3(0.60, 0.42, 0.28), vec3(0.86, 0.65, 0.42), propGrain + 0.5);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * propTone,
            propWood * 0.52);

        float metal = dot(IN.texBlend, vec3(
            auroraMetalMaterial(material1), auroraMetalMaterial(material2), auroraMetalMaterial(material3)));
	        float ironBars = dot(IN.texBlend, vec3(
	            auroraIronBarsMaterial(material1), auroraIronBarsMaterial(material2), auroraIronBarsMaterial(material3)));
	        float metalWear = auroraNoise(objectWorld / 36.0 + vec2(-19.0, 4.0));
        vec3 ironTone = mix(vec3(0.64, 0.68, 0.70), vec3(0.42, 0.46, 0.48), metalWear);
        vec3 barTone = mix(vec3(0.72, 0.74, 0.72), vec3(0.50, 0.52, 0.50), metalWear);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * ironTone,
            max(metal - ironBars * 0.75, 0.0) * 0.30);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * barTone,
            ironBars * 0.20);

	        float hay = dot(IN.texBlend, vec3(
	            auroraHayMaterial(material1), auroraHayMaterial(material2), auroraHayMaterial(material3)));
	        float hayCross = auroraFbm(vec2(objectWorld.x * 0.033, objectWorld.y * 0.017) + 23.0);
        float hayStrands = auroraNoise(vec2(IN.position.x + IN.position.z, IN.position.y) / 18.0);
        vec3 hayTone = mix(vec3(0.92, 0.82, 0.50), vec3(1.12, 0.98, 0.60), hayCross);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * hayTone * mix(0.94, 1.06, hayStrands),
            hay * 0.48);

        float fountain = dot(IN.texBlend, vec3(
            auroraFountainMaterial(material1), auroraFountainMaterial(material2), auroraFountainMaterial(material3)));
        float waterPulse = 0.5 + 0.5 * sin(elapsedTime * 1.8 + IN.position.x * 0.018 + IN.position.z * 0.013);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * vec3(0.72, 0.95, 1.18) + vec3(0.02, 0.05, 0.08) * waterPulse,
            fountain * 0.36);

	        float roof = dot(IN.texBlend, vec3(
	            auroraRoofMaterial(material1), auroraRoofMaterial(material2), auroraRoofMaterial(material3)));
	        float roofMacro = auroraFbm(objectWorld / 180.0 + vec2(21.0, -6.0)) - 0.5;
	        float roofFine = auroraNoise(objectWorld / 42.0) - 0.5;
        vec3 roofBreakup = vec3(roofMacro * 0.12 + roofFine * 0.035);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * (1.0 + roofBreakup), roof * 0.72);

	        float rockObject = dot(IN.texBlend, vec3(
	            auroraRockMaterial(material1), auroraRockMaterial(material2), auroraRockMaterial(material3)));
	        float stoneObject = dot(IN.texBlend, vec3(
	            auroraStoneLikeMaterial(material1), auroraStoneLikeMaterial(material2), auroraStoneLikeMaterial(material3)));
	        float rockFamily = auroraFbm(floor(objectWorld / 190.0) * 1.37 + vec2(3.0, 47.0));
        vec3 coolRock = vec3(0.70, 0.76, 0.80);
        vec3 warmRock = vec3(0.90, 0.82, 0.70);
	        float rockGrain = auroraNoise(objectWorld / 28.0 + vec2(19.0, -7.0)) - 0.5;
        vec3 rockTone = mix(coolRock, warmRock, rockFamily) * (0.92 + rockGrain * 0.12);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * rockTone,
            rockObject * 0.53);
	        float stoneBreakup = auroraFbm(objectWorld / 72.0 + vec2(-11.0, 8.0)) - 0.5;
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * (0.93 + vec3(stoneBreakup * 0.075)),
            stoneObject * 0.52);
    }

    // Aurora terrain treatment is applied to true scene terrain only, never actors or UI.
    if (auroraEnabled != 0 && isTerrain && !isWater && !isUnderwater) {
        vec2 terrainWorld = auroraDetailXz();
        float upward = clamp(abs(normalize(IN.normal).y), 0.0, 1.0);
        float slope = 1.0 - upward;
        float macro = auroraFbm(terrainWorld / 620.0) - 0.5;
        float micro = auroraNoise(terrainWorld / 34.0) - 0.5;
        float detail = (macro * 0.11 + micro * 0.018) * upward * auroraTerrainDetail;
        outputColor.rgb *= 1.0 + detail;

        // Separate natural green and warm earth without repainting authored materials.
        float green = clamp((outputColor.g - max(outputColor.r, outputColor.b)) * 3.5, 0.0, 1.0);
        float earth = clamp((outputColor.r - outputColor.b) * 2.0, 0.0, 1.0);
        outputColor.rgb *= mix(vec3(1.0), vec3(0.97, 1.035, 0.95), green * auroraTerrainDetail);
        outputColor.rgb *= mix(vec3(1.0), vec3(1.025, 1.0, 0.94), earth * auroraTerrainDetail * 0.6);

        // Selective living-ground color blending. Broad fields form gentle green
        // families, while bare earth gets compacted/warm and damp/cool patches.
        float biomeColor = auroraFbm(terrainWorld / 440.0 + vec2(4.0, 19.0));
        vec3 grassFamilyA = vec3(0.91, 1.075, 0.86);
        vec3 grassFamilyB = vec3(1.035, 1.105, 0.89);
        vec3 grassFamily = mix(grassFamilyA, grassFamilyB, smoothstep(0.42, 0.72, biomeColor));
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * grassFamily,
            green * 0.16 * auroraTerrainDetail);
        vec3 earthFamily = mix(vec3(0.92, 0.88, 0.80), vec3(1.07, 0.96, 0.82), biomeColor);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * earthFamily,
            earth * 0.12 * auroraMaterialDepth);

		// Material-scale detail: warped grain, compacted patches and sparse embedded flecks.
		// This is deliberately color-aware, so grass, earth and stone do not receive one generic pattern.
		float materialAmount = auroraMaterialDepth * upward;
		vec2 warpedUv = terrainWorld / 76.0;
		warpedUv += vec2(auroraNoise(warpedUv / 4.0), auroraNoise(warpedUv / 4.0 + 31.7)) * 0.62;
		float grain = auroraFbm(warpedUv) - 0.48;
		float compacted = smoothstep(0.54, 0.78, auroraFbm(terrainWorld / 235.0 + 12.0));
		float flecks = smoothstep(0.84, 0.94, auroraNoise(terrainWorld / 19.0));
		float neutral = 1.0 - clamp(green + earth, 0.0, 1.0);
		vec3 materialTint = vec3(grain * 0.085);
		materialTint += green * vec3(-0.026, 0.048, -0.034) * (grain + 0.30);
		materialTint += earth * vec3(0.052, 0.018, -0.032) * (grain + 0.24);
		materialTint += neutral * vec3(0.036, 0.030, 0.020) * grain;
		materialTint -= compacted * vec3(0.026, 0.021, 0.016);
			materialTint += flecks * mix(vec3(0.016), vec3(0.058, 0.052, 0.040), earth + neutral) * 0.55;
			outputColor.rgb *= 1.0 + materialTint * materialAmount;

            // Break up visible inherited tile/ground rows without blurring the whole
            // surface. The mask is strongest right on 128-unit tile edges and fades
            // immediately back into the authored material color.
            vec2 tileFrac = fract(terrainWorld / 128.0);
            vec2 edgeDist = min(tileFrac, 1.0 - tileFrac);
            float gridEdge = 1.0 - smoothstep(0.006, 0.040, min(edgeDist.x, edgeDist.y));
            float edgeNoise = auroraFbm(terrainWorld / 92.0 + vec2(31.0, -17.0)) - 0.5;
            vec3 edgeBlend = outputColor.rgb * (1.0 + edgeNoise * 0.075);
            outputColor.rgb = mix(outputColor.rgb, edgeBlend,
                gridEdge * upward * auroraMaterialDepth * (0.18 + 0.12 * max(green, earth)));

	        // Aurora 0.20 World Surface Overhaul: slope is a gentle biome influence,
	        // not a noisy rock overlay. Green ground dries/opens up on steeper faces;
        // earth/stone retains the warmer exposed edge. This makes banks, ridges and
        // field transitions feel authored while preserving OSRS tile readability.
        float slopeBreakup = auroraFbm(terrainWorld / 175.0 + vec2(8.3, -3.7));
        float exposedSlope = smoothstep(0.14, 0.68, slope + (slopeBreakup - 0.5) * 0.22);
        vec3 slopeTint = mix(vec3(0.94, 0.90, 0.76), vec3(1.07, 0.97, 0.82), earth);
        outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * slopeTint,
            exposedSlope * (0.12 * green + 0.075 * earth) * auroraMaterialDepth);

        // A sparse clustered cover impression adds life to broad grass tiles without
        // spawning geometry or turning the whole world into a noisy grass carpet.
        float flatGrass = dot(IN.texBlend, vec3(
            auroraFlatGrassMaterial(material1), auroraFlatGrassMaterial(material2), auroraFlatGrassMaterial(material3)));
        // 0.55.6: only the known GRASS_1/2/3 families get expanded cover. This is
        // shader-side clustered ground detail rather than new scene objects, avoiding
        // paths/farms/special tiles and the cost of spawning geometry.
        float clusterLow = mix(0.67, 0.59, flatGrass);
        float clusterHigh = mix(0.88, 0.84, flatGrass);
        float fineLow = mix(0.72, 0.64, flatGrass);
        float fineHigh = mix(0.92, 0.89, flatGrass);
        float coverClusters = smoothstep(clusterLow, clusterHigh, auroraFbm(terrainWorld / 52.0 + 17.0));
        float coverFine = smoothstep(fineLow, fineHigh, auroraNoise(terrainWorld / 13.0));
        float groundCover = coverClusters * coverFine * green * upward;
        float coverGain = mix(1.0, 1.50, flatGrass);
        outputColor.rgb *= 1.0 + vec3(-0.026, 0.052, -0.031) * groundCover * coverGain * auroraTerrainDetail;

        // Aurora World Detail 2.0. Surface decoration stays world-anchored and
        // fades aggressively against Detail distance and graphics-preset quality.
        if (auroraWorldDetailPass != 0) {
            float detailTileDistance = distance(IN.position, cameraPos) / 128.0;
            float detailLimit = max(18.0, auroraDetailDistance);
            float detailFade = 1.0 - smoothstep(detailLimit * 0.48, detailLimit * 0.94, detailTileDistance);
            float detailQuality = smoothstep(0.48, 0.92, auroraTerrainDetail);
            float worldDetail = detailFade * detailQuality * upward;

            float stoneTerrain = dot(IN.texBlend, vec3(
                auroraStoneLikeMaterial(material1), auroraStoneLikeMaterial(material2), auroraStoneLikeMaterial(material3)));
            float rockTerrain = dot(IN.texBlend, vec3(
                auroraRockMaterial(material1), auroraRockMaterial(material2), auroraRockMaterial(material3)));
            float snowTerrain = dot(IN.texBlend, vec3(
                auroraSnowMaterial(material1), auroraSnowMaterial(material2), auroraSnowMaterial(material3)));
            float mineralGround = clamp(neutral * 0.65 + stoneTerrain + rockTerrain, 0.0, 1.0);

            float pebbleSeed = auroraNoise(terrainWorld / 8.5 + vec2(7.0, 41.0));
            float pebblePatch = auroraNoise(terrainWorld / 37.0 + vec2(-12.0, 9.0));
            float pebbles = smoothstep(0.955, 0.992, pebbleSeed) * smoothstep(0.34, 0.74, pebblePatch) *
                clamp(earth * 0.58 + mineralGround * 0.90, 0.0, 1.0) * worldDetail;
            vec3 pebbleTone = mix(vec3(0.72, 0.67, 0.58), vec3(1.08, 1.03, 0.92), pebblePatch);
            outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * pebbleTone, pebbles * 0.52);

            float litterRegion = smoothstep(0.48, 0.73, auroraNoise(terrainWorld / 82.0 + vec2(19.0, -33.0)));
            float litterFleck = smoothstep(0.935, 0.987, auroraNoise(terrainWorld / 11.5 + vec2(-5.0, 22.0)));
            float litter = litterRegion * litterFleck * clamp(green * 0.68 + earth * 0.34, 0.0, 1.0) * worldDetail;
            outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * vec3(1.03, 0.77, 0.48), litter * 0.45);

            float tuftCell = auroraNoise(terrainWorld / 10.5 + vec2(28.0, 3.0));
            float tuftCluster = smoothstep(0.58, 0.82, auroraNoise(terrainWorld / 46.0 - vec2(16.0, 7.0)));
            float tufts = smoothstep(0.885, 0.975, tuftCell) * tuftCluster * flatGrass * green * worldDetail;
            outputColor.rgb *= 1.0 + vec3(-0.020, 0.050, -0.025) * tufts * 0.72;

            float mossField = smoothstep(0.60, 0.80, auroraNoise(terrainWorld / 74.0 + vec2(-27.0, 12.0)));
            float moss = mossField * mineralGround * (0.35 + auroraWetness * 0.65) * worldDetail;
            outputColor.rgb = mix(outputColor.rgb, outputColor.rgb * vec3(0.82, 1.05, 0.78), moss * 0.16);

            float flowerSeed = auroraNoise(terrainWorld / 6.5 + vec2(71.0, -19.0));
            float flowerCluster = smoothstep(0.60, 0.79, auroraNoise(terrainWorld / 58.0 + 8.0));
            float flowers = smoothstep(0.982, 0.997, flowerSeed) * flowerCluster * flatGrass * green * worldDetail;
            float flowerHue = auroraNoise(floor(terrainWorld / 6.5) + 117.0);
            vec3 flowerColor = mix(vec3(1.00, 0.86, 0.42), vec3(0.94, 0.72, 1.00), flowerHue);
            outputColor.rgb = mix(outputColor.rgb, flowerColor, flowers * 0.34);

            float snowPatch = auroraNoise(terrainWorld / 31.0 + vec2(9.0, 52.0)) - 0.5;
            float snowCrystal = smoothstep(0.90, 0.985, auroraNoise(terrainWorld / 7.0 - vec2(14.0, 3.0)));
            outputColor.rgb *= 1.0 + snowTerrain * worldDetail * (snowPatch * 0.060 + snowCrystal * 0.032);

            float wetMicro = smoothstep(0.53, 0.82, auroraNoise(terrainWorld / 27.0 + vec2(5.0, -11.0))) *
                auroraWetness * worldDetail * (1.0 - snowTerrain);
            float wetFacing = pow(max(dot(reflect(-lightDir, normalize(IN.normal)), viewDir), 0.0), 72.0);
            outputColor.rgb *= mix(vec3(1.0), vec3(0.91, 0.94, 0.92), wetMicro * 0.32);
            outputColor.rgb += lightColor * wetFacing * wetMicro * 0.020;
        }

        // Wet riverbanks blend out of the surrounding biome instead of forming a
        // hard dark rim. Wetness has a shorter reach on slopes where runoff exposes
        // soil and stone.
        float bankDamp = auroraWetness * upward * (0.45 + 0.55 * auroraFbm(terrainWorld / 98.0));
        outputColor.rgb *= mix(vec3(1.0), vec3(0.88, 0.94, 0.89), bankDamp * (0.42 * green + 0.62 * earth));

		// Sand and other bright warm ground receive broken deposits that interrupt
		// inherited continuous ripple rows without repainting darker earth paths.
		float sandMask = smoothstep(0.54, 0.82, max(outputColor.r, outputColor.g)) *
			smoothstep(0.02, 0.22, outputColor.r - outputColor.b) * (1.0 - green);
		float sandBreakup = auroraFbm(terrainWorld / 155.0 +
			vec2(auroraNoise(terrainWorld / 510.0), auroraNoise(terrainWorld / 510.0 + 7.0)));
		float sandPatch = smoothstep(0.34, 0.72, sandBreakup) - 0.5;
		outputColor.rgb *= 1.0 + sandMask * sandPatch * 0.16 * auroraMaterialDepth;

		// Warm, bright terrain receives a restrained wind-driven dust veil.
		float brightness = max(outputColor.r, max(outputColor.g, outputColor.b));
		float dryWarm = clamp((outputColor.r - outputColor.b) * 2.8, 0.0, 1.0) *
			clamp((brightness - 0.42) * 2.4, 0.0, 1.0);
		float dustBand = auroraNoise(terrainWorld / 210.0 + vec2(elapsedTime * 0.055, -elapsedTime * 0.025));
		float dust = smoothstep(0.60, 0.86, dustBand) * dryWarm * auroraDryDust;
		outputColor.rgb = mix(outputColor.rgb, vec3(0.72, 0.62, 0.43), dust * 0.12);
    }

    outputColor.rgb = clamp(outputColor.rgb, 0, 1);

    // Skip unnecessary color conversion if possible
    if (saturation != 1 || contrast != 1) {
        vec3 hsv = srgbToHsv(outputColor.rgb);

        // Apply saturation setting
        hsv.y *= saturation;

        // Apply contrast setting
        if (hsv.z > 0.5) {
            hsv.z = 0.5 + ((hsv.z - 0.5) * contrast);
        } else {
            hsv.z = 0.5 - ((0.5 - hsv.z) * contrast);
        }

        outputColor.rgb = hsvToSrgb(hsv);
    }

    outputColor.rgb = colorBlindnessCompensation(outputColor.rgb);

    #if APPLY_COLOR_FILTER
        outputColor.rgb = applyColorFilter(outputColor.rgb);
    #endif

    #if WIREFRAME
        outputColor.rgb *= wireframeMask();
    #endif

    // Apply either Aurora aerial perspective or the inherited distance-fog model.
    if (!isUnderwater) {
        float distance = distance(IN.position, cameraPos);
		float combinedFog;
		if (auroraEnabled != 0 && auroraAtmosphereEnabled != 0) {
			float clearRadius = 900.0;
			float opticalDistance = max(distance - clearRadius, 0.0);
			float horizon = 1.0 - clamp(abs(viewDir.y), 0.0, 1.0);
			float density = mix(0.000025, 0.000115, auroraHaze);
			combinedFog = 1.0 - exp(-opticalDistance * density * mix(0.72, 1.28, horizon));

			// Aurora 0.9: the old pseudo-volumetric mist was intentionally removed.
			// It read as a texture painted onto terrain. The control is retained for
			// compatibility but contributes nothing until true depth-volume fog exists.


			// Preserve expanded views rather than ending them at an opaque fog wall.
			combinedFog = min(combinedFog, mix(0.58, 0.86, auroraHaze));
			float sunFacing = pow(max(dot(-viewDir, lightDir), 0.0), 8.0);
			float hazeClock = auroraTime();
            float hazeSunHeight = sin((hazeClock - 0.25) * 6.28318530718);
            float hazeDaylight = smoothstep(-0.18, 0.12, hazeSunHeight);
            vec3 horizonBlue = mix(vec3(0.20, 0.28, 0.42), fogColor, hazeDaylight);
            float twilightHaze = exp(-pow(abs(hazeSunHeight) * 3.2, 2.0));
            vec3 atmosphericColor = mix(horizonBlue, vec3(0.92, 0.47, 0.28), twilightHaze * 0.24) + lightColor * sunFacing * 0.14;
            vec3 overcastTint = mix(vec3(0.23, 0.29, 0.36), vec3(0.60, 0.66, 0.70), hazeDaylight);
            atmosphericColor = mix(atmosphericColor, overcastTint,
                auroraCloudCover * (0.18 + auroraWetness * 0.28));
			outputColor.rgb = mix(outputColor.rgb, atmosphericColor, combinedFog);
		} else {
			float closeFadeDistance = 1500;
			float groundFog = 1.0 - clamp((IN.position.y - groundFogStart) / (groundFogEnd - groundFogStart), 0.0, 1.0);
			groundFog = mix(0.0, groundFogOpacity, groundFog);
			groundFog *= clamp(distance / closeFadeDistance, 0.0, 1.0);
			float fogAmount = calculateFogAmount(IN.position);
			combinedFog = 1 - (1 - fogAmount) * (1 - groundFog);
			outputColor.rgb = mix(outputColor.rgb, fogColor, combinedFog);
		}

        // Aurora material/render diagnostic. Unlike the old far-edge-only
        // marker, this cannot be missed if scene_frag.glsl is the live scene path.
        if (auroraEnabled != 0 && auroraLodDebug != 0) {
            float auroraKnownMaterial = clamp(
                auroraBroadleafMaterial(material1) + auroraBroadleafMaterial(material2) + auroraBroadleafMaterial(material3) +
                auroraWillowMaterial(material1) + auroraWillowMaterial(material2) + auroraWillowMaterial(material3) +
                auroraEvergreenMaterial(material1) + auroraEvergreenMaterial(material2) + auroraEvergreenMaterial(material3) +
                auroraYewMaterial(material1) + auroraYewMaterial(material2) + auroraYewMaterial(material3) +
                auroraMapleMaterial(material1) + auroraMapleMaterial(material2) + auroraMapleMaterial(material3) +
                auroraMagicLeavesMaterial(material1) + auroraMagicLeavesMaterial(material2) + auroraMagicLeavesMaterial(material3) +
                auroraHedgeMaterial(material1) + auroraHedgeMaterial(material2) + auroraHedgeMaterial(material3) +
                auroraBarkMaterial(material1) + auroraBarkMaterial(material2) + auroraBarkMaterial(material3) +
                auroraWettableMaterial(material1) + auroraWettableMaterial(material2) + auroraWettableMaterial(material3) +
                auroraPropWoodMaterial(material1) + auroraPropWoodMaterial(material2) + auroraPropWoodMaterial(material3) +
                auroraMetalMaterial(material1) + auroraMetalMaterial(material2) + auroraMetalMaterial(material3) +
                auroraIronBarsMaterial(material1) + auroraIronBarsMaterial(material2) + auroraIronBarsMaterial(material3) +
                auroraHayMaterial(material1) + auroraHayMaterial(material2) + auroraHayMaterial(material3) +
                auroraRockMaterial(material1) + auroraRockMaterial(material2) + auroraRockMaterial(material3) +
                auroraStoneLikeMaterial(material1) + auroraStoneLikeMaterial(material2) + auroraStoneLikeMaterial(material3) +
                auroraFountainMaterial(material1) + auroraFountainMaterial(material2) + auroraFountainMaterial(material3) +
                auroraRoofMaterial(material1) + auroraRoofMaterial(material2) + auroraRoofMaterial(material3), 0.0, 1.0);
            vec3 debugColor = isTerrain ? vec3(0.12, 0.42, 1.0) : mix(vec3(1.0, 0.05, 0.75), vec3(0.05, 1.0, 0.20), auroraKnownMaterial);
            outputColor.rgb = mix(outputColor.rgb, debugColor, 0.58);
        }

		if (isWater)
			outputColor.a = combinedFog + outputColor.a * (1 - combinedFog);
    }

    if (auroraEnabled != 0 && auroraColorGrade > 0.0) {
        float grade = auroraColorGrade;
        vec3 softContrast = outputColor.rgb * outputColor.rgb * (3.0 - 2.0 * outputColor.rgb);
        outputColor.rgb = mix(outputColor.rgb, softContrast, grade * 0.22);
        float luminance = dot(outputColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        outputColor.rgb = mix(vec3(luminance), outputColor.rgb, 1.0 + grade * 0.08);
    }

    if (auroraEnabled != 0) {
        // Lighting 2.0 HDR path: a slightly wider exposure window at night,
        // protected highlights at noon, and a luminance-aware shoulder before the
        // existing filmic curve. This gives sun/water/metal room to sparkle without
        // hard clipping the rest of the scene.
        float exposureClock = auroraTime();
        float exposureSun = sin((exposureClock - 0.25) * 6.28318530718);
        float exposureDay = smoothstep(-0.16, 0.16, exposureSun);
        float twilightExposure = exp(-pow(abs(exposureSun) * 3.4, 2.0));
        float autoExposure = mix(1.075, 0.955, exposureDay) * (1.0 + twilightExposure * 0.018);
        vec3 hdr = max(outputColor.rgb * autoExposure, vec3(0.0));
        float hdrPeak = max(max(hdr.r, hdr.g), hdr.b);
        float highlightGuard = 1.0 / (1.0 + max(hdrPeak - 1.0, 0.0) * 0.12);
        hdr *= mix(1.0, highlightGuard, 0.42);
        outputColor.rgb = hdr * (2.12 * hdr + 0.052) / (hdr * (1.96 * hdr + 0.575) + 0.142);
        outputColor.rgb = clamp(outputColor.rgb, 0.0, 1.0);
    }

    // Aurora 0.55.4 Weather 2.0. Rain uses three sparse depth layers with
    // slower fall speeds, mild wind slant, increasing apparent size toward the
    // bottom of the screen, and cheap water/ground splash cues. Snow intentionally
    // retains the 0.55.3 appearance the project already likes.
    if (auroraEnabled != 0 && auroraWeatherEnabled != 0 && (auroraRain > 0.001 || auroraSnow > 0.001)) {
        vec2 fp = gl_FragCoord.xy;
        vec2 res = max(vec2(sceneResolution), vec2(1.0));
        float screenDepth = 1.0 - clamp(fp.y / res.y, 0.0, 1.0);
        if (auroraRain > 0.001) {
            float storm = smoothstep(0.90, 0.995, auroraRain);
            float rainMask = 0.0;
            float baseWindSlant = sin(auroraWindDirection) * mix(0.035, 0.14, auroraWindStrength);
            for (int layer = 0; layer < 3; ++layer) {
                float lf = float(layer);
                float depthLayer = lf / 2.0;
                float spacing = mix(86.0, 50.0, depthLayer) * mix(1.0, 0.82, storm);
                float fallSpan = mix(205.0, 150.0, depthLayer);
                float baseSpeed = mix(54.0, 92.0, depthLayer) * mix(0.96, 1.12, storm);
                float layerSlant = (lf - 1.0) * 0.022;
                vec2 rainDir = normalize(vec2(baseWindSlant + layerSlant, 1.0));

                float baseTravelY = fp.y + elapsedTime * baseSpeed + lf * 73.0;
                float row = floor(baseTravelY / fallSpan);
                float column = floor((fp.x + lf * 113.0) / spacing);
                float cellSeed = auroraNoise(vec2(column * 0.83 + lf * 17.0, row * 1.37 + lf * 29.0));
                float occupancySeed = auroraNoise(vec2(column * 1.31 + 7.0, row * 1.73 + lf * 11.0));
                float occupancy = step(mix(0.50, 0.24, storm), occupancySeed);
                float speed = baseSpeed * mix(0.80, 1.18, cellSeed);
                float travelX = fp.x + rainDir.x * elapsedTime * speed + cellSeed * spacing * 0.62 + lf * 97.0;
                float localX = abs(fract(travelX / spacing) - (0.22 + auroraNoise(vec2(column + 19.0, row + 37.0)) * 0.56));
                float fall = fract((fp.y + elapsedTime * speed + cellSeed * fallSpan * 1.83) / fallSpan);
                float streakLen = mix(0.10, 0.23, depthLayer) * mix(0.86, 1.18, screenDepth);
                float thin = 1.0 - smoothstep(0.010, mix(0.026, 0.046, screenDepth), localX);
                float streak = occupancy * thin * smoothstep(0.08, 0.19, fall) *
                    (1.0 - smoothstep(0.19 + streakLen, 0.26 + streakLen, fall));
                rainMask += streak * mix(0.26, 0.70, depthLayer);
            }
            rainMask = clamp(rainMask, 0.0, 1.0);
            float rainAlpha = rainMask * auroraRain * mix(0.105, 0.18, storm);
            outputColor.rgb = mix(outputColor.rgb, vec3(0.68, 0.78, 0.88), rainAlpha);

            // Cheap rain impact response: tiny intermittent rings on water plus a
            // subtle lower-screen splash cue. No CPU particles or collision objects.
            if (isWater) {
                vec2 splashCell = floor(IN.position.xz / 42.0);
                float splashSeed = auroraNoise(splashCell + floor(elapsedTime * 2.4));
                float splashPhase = fract(elapsedTime * 2.4 + splashSeed);
                float splashRing = 1.0 - smoothstep(0.035, 0.11, abs(fract(length(fract(IN.position.xz / 42.0) - 0.5) * 2.0 - splashPhase) - 0.5));
                outputColor.rgb += vec3(0.055, 0.075, 0.095) * splashRing * auroraRain * 0.20;
            }
            float bottomSplash = smoothstep(0.78, 0.98, screenDepth) *
                smoothstep(0.86, 0.98, auroraNoise(floor(fp / vec2(47.0, 19.0)) + floor(elapsedTime * 3.0)));
            outputColor.rgb += vec3(0.05, 0.065, 0.08) * bottomSplash * auroraRain * 0.12;

            // Storm-only lower-screen splatter. Independent cells/phases avoid the old
            // synchronized arrow-sheet look while suggesting near-camera impacts.
            float bottom20 = smoothstep(0.80, 0.98, screenDepth);
            vec2 splatCell = floor(fp / vec2(36.0, 22.0));
            float splatSeed = auroraNoise(splatCell * vec2(1.37, 1.91) + 43.0);
            float splatPhase = fract(elapsedTime * mix(1.8, 3.4, splatSeed) + splatSeed * 7.0);
            vec2 splatLocal = fract(fp / vec2(36.0, 22.0)) - 0.5;
            float splatArc = (1.0 - smoothstep(0.08, 0.22, abs(length(splatLocal * vec2(1.0, 1.8)) - splatPhase * 0.24))) *
                (1.0 - smoothstep(0.18, 0.46, splatPhase));
            float splatGate = step(0.76, splatSeed) * storm * bottom20;
            outputColor.rgb += vec3(0.11, 0.14, 0.17) * splatArc * splatGate * 0.24;

            // Storm is denser, not a synchronized faster sheet. Keep the murky sky
            // and occasional double-flash lightning from 0.55.4.
            float stormBucket = floor(elapsedTime / 8.0);
            float stormSeed = auroraNoise(vec2(stormBucket, 91.7));
            float stormPhase = fract(elapsedTime / 8.0);
            float flashA = exp(-pow((stormPhase - 0.10) / 0.018, 2.0));
            float flashB = 0.52 * exp(-pow((stormPhase - 0.145) / 0.028, 2.0));
            float auroraLightning = storm * step(0.80, stormSeed) * clamp(flashA + flashB, 0.0, 1.0);
            outputColor.rgb = mix(outputColor.rgb, vec3(dot(outputColor.rgb, vec3(0.299, 0.587, 0.114))) * vec3(0.72, 0.76, 0.82), storm * 0.18);
            outputColor.rgb += vec3(0.32, 0.37, 0.46) * auroraLightning * 0.55;
        }
        if (auroraSnow > 0.001) {
            vec2 drift = vec2(sin(elapsedTime * 0.55) * 22.0, elapsedTime * 34.0);
            vec2 sp = (fp + drift) / 18.0;
            vec2 cell = floor(sp);
            vec2 local = fract(sp) - vec2(auroraNoise(cell + 11.0), auroraNoise(cell + 37.0));
            float flake = 1.0 - smoothstep(0.035, 0.13, length(local));
            outputColor.rgb = mix(outputColor.rgb, vec3(0.94, 0.97, 1.0), flake * auroraSnow * 0.34);
        }
    }

    // World Detail 2.0 environmental motes. One sparse screen-space layer gives
    // fair-weather pollen/dust a sense of depth without spawning particle objects.
    // It stays off in precipitation and never overlays water.
    if (auroraEnabled != 0 && auroraWorldDetailPass != 0 && !isWater && !isUnderwater &&
        auroraRain < 0.02 && auroraSnow < 0.02) {
        float moteQuality = smoothstep(0.62, 0.98, auroraTerrainDetail);
        float moteWeather = (1.0 - clamp(auroraCloudCover * 0.72, 0.0, 0.82)) * moteQuality;
        if (moteWeather > 0.01) {
            vec2 moteP = (gl_FragCoord.xy + vec2(elapsedTime * 5.5, -elapsedTime * 9.0)) / 43.0;
            vec2 moteCell = floor(moteP);
            vec2 moteLocal = fract(moteP) - 0.5;
            float moteSeed = auroraHash(moteCell + 203.0);
            vec2 moteOffset = vec2(auroraHash(moteCell + 17.0), auroraHash(moteCell + 71.0)) - 0.5;
            moteLocal -= moteOffset * 0.55;
            float mote = step(0.982, moteSeed) * (1.0 - smoothstep(0.025, 0.085, length(moteLocal)));
            float motePulse = 0.55 + 0.45 * sin(elapsedTime * 1.1 + moteSeed * 19.0);
            outputColor.rgb += vec3(1.0, 0.92, 0.66) * mote * motePulse * moteWeather * 0.020;
        }
    }

    outputColor.rgb = pow(outputColor.rgb, vec3(gammaCorrection));

    #if WINDOWS_HDR_CORRECTION
        outputColor.rgb = windowsHdrCorrection(outputColor.rgb);
    #endif

    FragColor = outputColor;
}
