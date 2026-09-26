/*
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
#include <uniforms/global.glsl>
#include <uniforms/materials.glsl>
#include <uniforms/water_types.glsl>

#include <utils/lights.glsl>
#include <utils/misc.glsl>

// Water-local noise is intentionally independent from the terrain noise declared by scene_frag.
float auroraWaterHash(vec2 p) {
    return fract(sin(dot(p, vec2(41.7, 289.1))) * 45758.5453);
}

float auroraWaterNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(auroraWaterHash(i), auroraWaterHash(i + vec2(1, 0)), f.x),
               mix(auroraWaterHash(i + vec2(0, 1)), auroraWaterHash(i + vec2(1, 1)), f.x), f.y);
}

vec4 sampleWater(int waterTypeIndex, vec3 viewDir) {
    WaterType waterType = getWaterType(waterTypeIndex);
    bool auroraCalm = auroraWaterPreset == 0;
    bool auroraNatural = auroraWaterPreset == 1;
    bool auroraCoastal = auroraWaterPreset == 2;
    bool auroraOcean3 = auroraWaterPreset == 3;
    bool auroraStormy = auroraWaterPreset == 4;

    // Aurora 0.55.5: explicit per-preset clocks. Stormy and Active Coast retain
    // their 0.55.4 cadence. Natural is only ~5% faster. Ocean 3 regains visible
    // motion without returning to the old runaway startup speed.
    float surfaceCadence = 1.0;
    float flowCadence = 1.0;
    if (auroraEnabled != 0) {
        if (auroraCalm) {
            surfaceCadence = 1.48;
            flowCadence = 1.58;
        } else if (auroraNatural) {
            surfaceCadence = 1.95; // about 5% faster than 2.05
            flowCadence = 2.13;    // about 5% faster than 2.24
        } else if (auroraOcean3) {
            // 0.58.3: +200% over the current Ocean 3.0 cadence = 3x current speed.
            // Keep all clocks world-space stable; only temporal cadence changes.
            surfaceCadence = 4.59;
            flowCadence = 5.10;
        } else if (auroraStormy) {
            // 0.55.6: Stormy appearance is unchanged; only cadence is +30%.
            surfaceCadence = 1.58;
            flowCadence = 1.72;
        } else {
            // Active Coast remains exactly at the 0.55.5 cadence.
            surfaceCadence = 2.05;
            flowCadence = 2.24;
        }
    }
    vec2 uv1 = worldUvs(3).yx - animationFrame(28 * waterType.duration * surfaceCadence);
    vec2 uv2 = worldUvs(3) + animationFrame(24 * waterType.duration * surfaceCadence);
    vec2 uv3 = IN.uv;

    vec2 flowMapUv = worldUvs(15) + animationFrame(50 * waterType.duration * flowCadence);
    float flowMapStrength = 0.025;

    vec2 uvFlow = texture(textureArray, vec3(flowMapUv, MAT_WATER_FLOW_MAP.colorMap)).xy;
    uv1 += uvFlow * flowMapStrength;
    uv2 += uvFlow * flowMapStrength;
    uv3 += uvFlow * flowMapStrength;

    // get diffuse textures
    vec3 n1 = linearToSrgb(texture(textureArray, vec3(uv1, waterType.normalMap)).xyz);
    vec3 n2 = linearToSrgb(texture(textureArray, vec3(uv2, waterType.normalMap)).xyz);
    float foamMask = texture(textureArray, vec3(uv3, MAT_WATER_FOAM.colorMap)).r;

    // normals
    n1 = -vec3((n1.x * 2 - 1) * waterType.normalStrength, n1.z, (n1.y * 2 - 1) * waterType.normalStrength);
    n2 = -vec3((n2.x * 2 - 1) * waterType.normalStrength, n2.z, (n2.y * 2 - 1) * waterType.normalStrength);
    vec3 normals = normalize(n1 + n2);

    float auroraWaveCrest = 0.0;
    float auroraCrossCollision = 0.0;
    if (auroraEnabled != 0 && auroraWaterDynamics > 0.0) {
        // 0.55.4: never rotate the world sampling field over time. The previous
        // windRotation made huge world coordinates slide through the wave functions
        // as wind direction evolved, which is why water could begin very fast and
        // mysteriously settle minutes later. Wind now changes amplitudes only.
        vec2 wp = IN.position.xz;
        vec2 windDir = normalize(vec2(cos(auroraWindDirection), sin(auroraWindDirection)) + vec2(0.0001));
        float windAlignA = 0.82 + 0.18 * abs(dot(normalize(vec2(0.91, 0.41)), windDir));
        float windAlignB = 0.84 + 0.16 * abs(dot(normalize(vec2(-0.36, 0.93)), windDir));
        // Wind changes chop/height, not the passage of time. Keeping the clock stable
        // prevents water from seeming to speed up and slow down as weather transitions.
        float windAmplitudeScale = mix(0.86, 1.14, auroraWindStrength);
        float auroraWaveRate = 0.46;
        if (auroraCalm)
            auroraWaveRate = 0.62;
        else if (auroraNatural)
            auroraWaveRate = 0.483; // +5%
        else if (auroraOcean3)
            auroraWaveRate = 1.44;  // 0.58.3: +200% = 3x current Ocean 3.0 temporal rate
        else if (auroraStormy)
            auroraWaveRate = 0.598; // 0.55.6: +30% without changing Stormy's shape
        // Active Coast deliberately remains 0.46.
        float auroraWaveTime = elapsedTime * auroraWaveRate;
        float warp = auroraWaterNoise(wp / 410.0 + vec2(auroraWaveTime * 0.025, -auroraWaveTime * 0.018)) - 0.5;
        float swellA = sin(dot(wp, normalize(vec2(0.91, 0.41))) * 0.0058 + auroraWaveTime * 0.62 + warp * 2.4) * windAlignA;
        float swellB = sin(dot(wp, normalize(vec2(-0.36, 0.93))) * 0.0096 - auroraWaveTime * 0.81 - warp * 1.7) * windAlignB;
        float longSwell = sin(dot(wp, normalize(vec2(0.74, 0.67))) * 0.0031 + auroraWaveTime * 0.38 + warp * 1.15);
        float chopA = sin(dot(wp, normalize(vec2(0.64, -0.77))) * 0.023 + auroraWaveTime * 1.26 + swellB * 0.52);
        float chopB = sin(dot(wp, normalize(vec2(-0.82, -0.57))) * 0.039 - auroraWaveTime * 1.68 + swellA * 0.36);
        float ripple = auroraWaterNoise(wp / 48.0 + vec2(-auroraWaveTime * 0.12, auroraWaveTime * 0.09)) - 0.5;
		float windPatch = smoothstep(0.26, 0.78, auroraWaterNoise(wp / 690.0 + vec2(auroraWaveTime * 0.010, 0.0)));
		float capillary = sin(dot(wp, normalize(vec2(0.28, 0.96))) * 0.086 + auroraWaveTime * 2.55 + warp * 3.0);
        // Aurora 0.11: two additional independent scales keep the ocean from reading as a tiled normal map.
        float megaSwell = sin(dot(wp, normalize(vec2(-0.18, 0.98))) * 0.00165 + auroraWaveTime * 0.205 + warp * 0.72);
        float crossSea = sin(dot(wp, normalize(vec2(0.97, -0.24))) * 0.0142 - auroraWaveTime * 0.96 + megaSwell * 0.48);
        // Ocean 3 only: intermittent opposing trains create crossing-sea events.
        float eventEnvelope = smoothstep(0.40, 0.76, auroraWaterNoise(wp / 1250.0 + vec2(auroraWaveTime * 0.0025, -auroraWaveTime * 0.0017)));
        float eventEnvelopeB = smoothstep(0.46, 0.80, auroraWaterNoise(wp / 860.0 + vec2(-auroraWaveTime * 0.0031, auroraWaveTime * 0.0022) + 37.0));
        float opposing = sin(dot(wp, normalize(vec2(-0.93, -0.37))) * 0.0074 - auroraWaveTime * 0.57 + warp * 1.1);
        float opposingB = sin(dot(wp, normalize(vec2(-0.41, 0.91))) * 0.0118 + auroraWaveTime * 0.73 - warp * 0.8);
        float eventEnvelopeC = smoothstep(0.52, 0.82, auroraWaterNoise(wp / 1040.0 + vec2(auroraWaveTime * 0.0017, auroraWaveTime * 0.0033) + 83.0));
        float crossingC = sin(dot(wp, normalize(vec2(0.22, -0.98))) * 0.0087 + auroraWaveTime * 0.66 + warp * 0.95);
        if (auroraOcean3) {
            crossSea += opposing * eventEnvelope * 0.88 + opposingB * eventEnvelopeB * 0.52 + crossingC * eventEnvelopeC * 0.46;
            float collisionA = eventEnvelope * pow(max(0.0, 1.0 - abs(swellA - opposing)), 2.0);
            float collisionB = eventEnvelopeB * pow(max(0.0, 1.0 - abs(swellB + opposingB)), 2.0);
            float collisionC = eventEnvelopeC * pow(max(0.0, 1.0 - abs(longSwell - crossingC)), 2.0);
            auroraCrossCollision = clamp(max(max(collisionA, collisionB), collisionC) + (collisionA * collisionB + collisionB * collisionC) * 0.42, 0.0, 1.0);
        }
        float microChop = sin(dot(wp, normalize(vec2(-0.58, 0.81))) * 0.061 + auroraWaveTime * 2.08 + chopA * 0.31);
        vec2 waveSlope = vec2(swellA * 0.46 + swellB * 0.27 + longSwell * 0.25 + megaSwell * 0.34 + crossSea * 0.16 + chopA * 0.20 + microChop * 0.08 + ripple * 0.22,
                              swellB * 0.43 - swellA * 0.25 + longSwell * 0.18 - megaSwell * 0.29 + crossSea * 0.15 + chopB * 0.20 - microChop * 0.07 - ripple * 0.20);
		waveSlope += vec2(capillary, -capillary * 0.74) * 0.055 * windPatch;
        normals.xz += waveSlope * (0.074 * auroraWaterDynamics * mix(0.72, 1.16, windPatch) * windAmplitudeScale);
        normals = normalize(normals);
		auroraWaveCrest = clamp((swellA + swellB + longSwell * 0.82 + megaSwell * 0.95 + crossSea * 0.58 + chopA * 0.58 + chopB * 0.44 + microChop * 0.28) * 0.175 + 0.50, 0.0, 1.0);
    }

    float lightDotNormals = dot(normals, lightDir);
    float downDotNormals = -normals.y;
    float viewDotNormals = dot(viewDir, normals);

    vec2 distortion = uvFlow * .00075;
    float shadow = sampleShadowMap(IN.position, distortion, lightDotNormals);
    // Very low-angle/moon shadows can stretch unnaturally across reflective water.
    // Keep them present, but soften them at night instead of treating water like land.
    float waterShadowClock = fract(auroraTimeOfDay +
        (auroraDayCycleEnabled != 0 ? elapsedTime * mix(0.00002, 0.00055, auroraDayCycleSpeed) : 0.0));
    float waterShadowSunHeight = sin((waterShadowClock - 0.25) * 6.28318530718);
    float waterShadowDaylight = smoothstep(-0.18, 0.12, waterShadowSunHeight);
    shadow *= mix(0.42, 1.0, waterShadowDaylight);
    float inverseShadow = 1 - shadow;

    vec3 vSpecularStrength = vec3(waterType.specularStrength);
    vec3 vSpecularGloss = vec3(waterType.specularGloss);
    float combinedSpecularStrength = waterType.specularStrength;

    // calculate lighting

    // ambient light
    vec3 ambientLightOut = ambientColor * ambientStrength;

    // directional light
    vec3 dirLightColor = lightColor * lightStrength;

    // apply shadows
    dirLightColor *= inverseShadow;

    vec3 lightColor = dirLightColor;
    vec3 lightOut = max(lightDotNormals, 0.0) * lightColor;

    // directional light specular
    vec3 lightReflectDir = reflect(-lightDir, normals);
    vec3 lightSpecularOut = lightColor * specular(IN.texBlend, viewDir, lightReflectDir, vSpecularGloss, vSpecularStrength);

    // point lights
    vec3 pointLightsOut = vec3(0);
    vec3 pointLightsSpecularOut = vec3(0);
    calculateLighting(IN.position, normals, viewDir, IN.texBlend, vSpecularGloss, vSpecularStrength, pointLightsOut, pointLightsSpecularOut);

    // sky light
    vec3 skyLightColor = fogColor.rgb;
    float skyLightStrength = 0.5;
    float skyDotNormals = downDotNormals;
    vec3 skyLightOut = max(skyDotNormals, 0.0) * skyLightColor * skyLightStrength;


    // lightning
    vec3 lightningColor = vec3(1.0, 1.0, 1.0);
    float lightningStrength = lightningBrightness;
    float lightningDotNormals = downDotNormals;
    vec3 lightningOut = max(lightningDotNormals, 0.0) * lightningColor * lightningStrength;


    // underglow
    vec3 underglowOut = underglowColor * max(normals.y, 0) * underglowStrength;


    // fresnel reflection
    float baseOpacity = 0.4;
	float planeFacing = clamp(abs(viewDir.y), 0.0, 1.0);
	float grazingReflection = pow(1.0 - planeFacing, 2.2);
	float microReflection = pow(1.0 - clamp(abs(viewDotNormals), 0.0, 1.0), 3.0);
	// Keep the attractive overhead reflection while correctly strengthening grazing views.
    float finalFresnel = clamp(0.44 + grazingReflection * 0.48 + microReflection * 0.12, 0.0, 1.0);
    vec3 surfaceColor = vec3(0);

    // add sky gradient
    if (finalFresnel < 0.5) {
        surfaceColor = mix(waterColorDark, waterColorMid, finalFresnel * 2);
    } else {
        surfaceColor = mix(waterColorMid, waterColorLight, (finalFresnel - 0.5) * 2);
    }

    // Lighting/Water 2.0 reflection path. Keep the attractive 117-style Fresnel
    // response, but let the reflected palette follow Aurora's celestial clock and
    // weather instead of staying permanently daytime-blue.
    if (auroraEnabled != 0 && auroraWaterReflection > 0.0) {
        float reflectClock = fract(auroraTimeOfDay +
            (auroraDayCycleEnabled != 0 ? elapsedTime * mix(0.00002, 0.00055, auroraDayCycleSpeed) : 0.0));
        float reflectSunHeight = sin((reflectClock - 0.25) * 6.28318530718);
        float reflectDaylight = smoothstep(-0.18, 0.12, reflectSunHeight);
        float reflectTwilight = exp(-pow(abs(reflectSunHeight) * 3.25, 2.0));
        vec3 nightDeep = vec3(0.010, 0.040, 0.095);
        vec3 nightHorizon = vec3(0.090, 0.160, 0.285);
        vec3 dayDeep = vec3(0.018, 0.105, 0.190);
        vec3 dayHorizon = vec3(0.225, 0.555, 0.875);
        vec3 auroraDeep = mix(nightDeep, dayDeep, reflectDaylight);
        vec3 auroraHorizon = mix(nightHorizon, dayHorizon, reflectDaylight);
        auroraHorizon = mix(auroraHorizon, vec3(0.78, 0.39, 0.20), reflectTwilight * reflectDaylight * 0.22);
        vec3 reflectedSky = mix(auroraDeep, auroraHorizon, smoothstep(0.20, 0.96, finalFresnel));
        float weatherDim = 1.0;
        if (auroraWeatherEnabled != 0) {
            weatherDim = mix(1.0, 0.76, auroraCloudCover * 0.58);
            vec2 cloudMotion = vec2(elapsedTime * 55.0, elapsedTime * 21.0);
            vec2 cloudUv = ((IN.position.xz) + cloudMotion) / 980.0;
            float reflectedCloud = smoothstep(mix(0.76, 0.42, auroraCloudCover),
                mix(0.92, 0.62, auroraCloudCover), auroraWaterNoise(cloudUv));
            vec3 cloudReflection = mix(vec3(0.30, 0.36, 0.46), vec3(0.76, 0.83, 0.90), reflectDaylight);
            reflectedSky = mix(reflectedSky, cloudReflection, reflectedCloud * 0.25 * finalFresnel);
        }
        vec2 reflectionWorld = IN.position.xz;
        float reflectionBreakup = 0.90 + 0.10 * auroraWaterNoise(reflectionWorld / 76.0 + vec2(elapsedTime * 0.006, -elapsedTime * 0.004));
        surfaceColor = mix(surfaceColor, reflectedSky * weatherDim * reflectionBreakup,
            clamp(auroraWaterReflection * (0.36 + finalFresnel * 0.48), 0.0, 0.94));
    }

    vec3 surfaceColorOut = surfaceColor * max(combinedSpecularStrength, 0.2);


    // apply lighting
    vec3 compositeLight = ambientLightOut + lightOut + lightSpecularOut + skyLightOut + lightningOut +
    underglowOut + pointLightsOut + pointLightsSpecularOut + surfaceColorOut;

    vec3 baseColor = waterType.surfaceColor * compositeLight;
    baseColor = mix(baseColor, surfaceColor, waterType.fresnelAmount);
	if (auroraEnabled != 0 && auroraWaterDynamics > 0.0) {
        vec2 waterWorld = IN.position.xz;
		float basin = auroraWaterNoise(waterWorld / 520.0 + vec2(elapsedTime * 0.0075, -elapsedTime * 0.0055)) - 0.5;
		baseColor *= 1.0 + basin * 0.085 * auroraWaterDynamics;
		float glintDot = max(dot(reflect(-lightDir, normals), viewDir), 0.0);
		float glint = pow(glintDot, 112.0);
		float sparkle = pow(glintDot, 420.0) * smoothstep(0.35, 0.86, auroraWaterNoise(waterWorld / 22.0 + elapsedTime * 0.038));
		baseColor += lightColor * (glint * 0.27 + sparkle * 0.18) * auroraWaterDynamics * inverseShadow;
	}
    if (waterType.fresnelAmount == 0.85)
        baseColor *= .75f; // Sailing hack
    float shoreLineMask = 1 - dot(IN.texBlend, (fAlphaBiasHsl & 127) / 127.f);

    // Water 3.1 depth coloration. The shoreline blend mask is the only cheap,
    // stable per-fragment proxy for depth available in this surface pass, so use
    // it as a broad shallow/deep transition rather than drawing obvious bands.
    if (auroraEnabled != 0 && !waterType.isFlat) {
        vec2 depthWorld = IN.position.xz;
        float depthNoise = auroraWaterNoise(depthWorld / 180.0) - 0.5;
        float shallowWater = smoothstep(0.055, 0.58, shoreLineMask + depthNoise * 0.055);
        float submergedView = 1.0 - finalFresnel;
        vec3 deepTint = mix(waterType.depthColor, vec3(0.018, 0.105, 0.155), 0.34);
        vec3 shallowTint = mix(waterType.surfaceColor, vec3(0.17, 0.50, 0.56), 0.26);
        vec3 depthTint = mix(deepTint, shallowTint, shallowWater);
        float depthColorStrength = clamp(auroraWaterClarity * 0.12 + 0.07, 0.07, 0.22) * submergedView;
        baseColor = mix(baseColor, depthTint * (ambientLightOut + skyLightOut * 0.60 + vec3(0.24)), depthColorStrength);
    }

    float maxFoamAmount = 0.8;
    float foamAmount = min(shoreLineMask, maxFoamAmount);
    float foamDistance = 0.7;
    vec3 foamColor = waterType.foamColor;
    foamColor = foamColor * foamMask * compositeLight;
    foamAmount = clamp(pow(1.0 - ((1.0 - foamAmount) / foamDistance), 3), 0.0, 1.0) * waterType.hasFoam;
    foamAmount *= foamColor.r;
	if (auroraEnabled != 0)
		foamAmount = clamp(foamAmount * (1.0 + auroraWaterDynamics * 0.35), 0.0, 1.0);
	if (auroraEnabled != 0 && auroraShoreFoam > 0.0 && !waterType.isFlat) {
		float shoreBand = smoothstep(0.012, 0.24, shoreLineMask) *
			(1.0 - smoothstep(0.50, 0.84, shoreLineMask));
        vec2 waterWorld = IN.position.xz;
		float foamBreakup = auroraWaterNoise(waterWorld / 41.0);
        float foamCell = auroraWaterNoise(waterWorld / 23.0 + vec2(elapsedTime * 0.009, -elapsedTime * 0.006));
        float foamFine = auroraWaterNoise(waterWorld / 12.5 + vec2(-elapsedTime * 0.014, elapsedTime * 0.010));
        float foamMacro = auroraWaterNoise(waterWorld / 96.0 - vec2(elapsedTime * 0.005, elapsedTime * 0.0025));
		// Phase travels across the shoreline mask, producing a visible incoming breaker
        // and thinner backwash. Noise warps the phase itself so it cannot resolve into
        // uniform contour lines around polygonal shore geometry.
		float shorelineWarp = (auroraWaterNoise(waterWorld / 115.0 + elapsedTime * 0.010) - 0.5) * 3.6;
		float shoreTime = elapsedTime * (auroraOcean3 ? 1.44 : (auroraStormy ? 0.936 : 0.72));
		float incomingPhase = sin(shoreLineMask * 17.0 - shoreTime * 1.95 + shorelineWarp);
		float retreatPhase = sin(shoreLineMask * 13.2 + shoreTime * 1.05 + 1.7 - shorelineWarp * 0.35);
		float incoming = smoothstep(0.26, 0.80, incomingPhase) * shoreBand;
		float retreat = smoothstep(0.52, 0.91, retreatPhase) * shoreBand * (auroraOcean3 ? 0.44 : 0.34);
        float foamCut = smoothstep(0.30, 0.72, foamBreakup) * smoothstep(0.18, 0.82, foamMacro);
        float foamFilaments = smoothstep(0.34, 0.84, foamFine);
		float lace = clamp(foamCut * (0.52 + 0.48 * foamFilaments), 0.0, 1.0);
        float residual = smoothstep(0.50, 0.80, foamMacro) * shoreBand * smoothstep(0.22, 0.90, retreatPhase) *
            (0.11 + 0.13 * foamFilaments);

        // Aurora 0.55.3 Shore Reflection: use WORLD-SPACE incoming fronts and a
        // much weaker reflected train. This avoids drawing repeated shoreline-mask
        // contour lines while still producing the roll-in / backwash crossing effect.
        vec2 shoreWind = normalize(vec2(cos(auroraWindDirection), sin(auroraWindDirection)) + vec2(0.001));
        vec2 incomingAxis = normalize(vec2(-shoreWind.y, shoreWind.x));
        vec2 reboundAxis = normalize(-incomingAxis + shoreWind * 0.24);
        float worldWarp = (auroraWaterNoise(waterWorld / 260.0 + shoreWind * shoreTime * 0.0035) - 0.5) * 1.45;
        float incomingWorldPhase = sin(dot(waterWorld, incomingAxis) / 138.0 - shoreTime * 0.54 + worldWarp);
        float reboundWorldPhase = sin(dot(waterWorld, reboundAxis) / 158.0 - shoreTime * 0.25 + 2.15 - worldWarp * 0.42);
        float edgeZone = smoothstep(0.014, 0.105, shoreLineMask) *
            (1.0 - smoothstep(0.54, 0.80, shoreLineMask));
        float frontBreakup = smoothstep(0.24, 0.74, foamBreakup) *
            smoothstep(0.16, 0.80, foamMacro) * (0.68 + 0.32 * foamFilaments);
        float incomingFront = smoothstep(0.40, 0.86, incomingWorldPhase) * edgeZone * frontBreakup;
        float reboundFront = smoothstep(0.58, 0.92, reboundWorldPhase) * edgeZone * frontBreakup *
            (auroraOcean3 ? 0.32 : 0.21);
        float crossingWash = incomingFront + reboundFront + incomingFront * reboundFront * 0.40;
        baseColor *= 1.0 + crossingWash * (auroraOcean3 ? 0.060 : 0.036) * clamp(auroraShoreFoam, 0.0, 1.7);
        normals = normalize(normals + vec3(
            incomingAxis.x * incomingFront * 0.022 + reboundAxis.x * reboundFront * 0.012,
            0.0,
            incomingAxis.y * incomingFront * 0.022 + reboundAxis.y * reboundFront * 0.012));

        // Restore the attractive 117-style shoreline sparkle as a separate narrow
        // specular ribbon. It is driven by real wave normals and broken by multiple
        // noise scales, so it sparkles at the water edge without becoming solid foam.
        float shoreGlintDot = max(dot(reflect(-lightDir, normals), viewDir), 0.0);
        float shoreGlint = pow(shoreGlintDot, mix(30.0, 72.0, waterShadowDaylight));
        float shoreGrazing = pow(1.0 - clamp(abs(viewDir.y), 0.0, 1.0), 1.35);
        float shimmerNoise = smoothstep(0.38, 0.80, foamFine) *
            (0.42 + 0.58 * smoothstep(0.26, 0.76, auroraWaterNoise(waterWorld / 8.5 + vec2(elapsedTime * 0.021, -elapsedTime * 0.016))));
        float shimmerRibbon = edgeZone * frontBreakup * shimmerNoise *
            clamp(0.12 + shoreGlint * 0.88 + shoreGrazing * 0.16, 0.0, 1.0);
        vec3 shoreMoon = vec3(0.58, 0.70, 0.96);
        vec3 shoreSun = vec3(1.00, 0.88, 0.66);
        baseColor += mix(shoreMoon, shoreSun, waterShadowDaylight) * shimmerRibbon *
            (0.15 + 0.16 * auroraWaterReflection) * inverseShadow;

        float auroraFoam = ((incoming + retreat) * lace + residual) * clamp(auroraShoreFoam, 0.0, 1.7);
        auroraFoam += (incomingFront * 0.20 + reboundFront * 0.105) * lace *
            clamp(auroraShoreFoam, 0.0, 1.7);
        if (auroraOcean3) {
            // Ocean 3.3: a deeper family of irregular precursor breakers.
            // Separate warped phases keep the offshore layers from becoming one repeated
            // contour pattern and heavily gate radial/shore-to-sea streaks.
            // Aurora 0.16 Ocean 3.6: deliberately NON-uniform coastal sequencing.
            // shoreLineMask is larger toward shore; explicit irregular centers avoid
            // the repeated dashed-contour look produced by periodic sine bands.
            // Aurora 0.18 Coastal Breakers 4.0.
            // Near foam may hug the coast, but the far breaker families are WORLD-SPACE
            // incoming wave fronts merely gated by coastal proximity. They therefore stop
            // copying every polygonal shoreline corner into pointed nested contours.
            float coastalGate = smoothstep(0.002, 0.035, shoreLineMask) *
                (1.0 - smoothstep(0.72, 0.88, shoreLineMask));
            vec2 coastP = waterWorld;
            float coastWarp = auroraWaterNoise(coastP / 230.0 + vec2(shoreTime * 0.003, -shoreTime * 0.002)) - 0.5;
            float coastWarp2 = auroraWaterNoise(coastP / 410.0 + vec2(-shoreTime * 0.0015, shoreTime * 0.001)) - 0.5;
            float nearD = shoreLineMask + coastWarp * 0.040 + coastWarp2 * 0.025;

            // Coastline 5.0: stop drawing bright nested contour lines right on every
            // polygon corner. Near-shore foam is now a broad, broken shallow-water field.
            float shallowZone = smoothstep(0.30, 0.46, shoreLineMask) *
                (1.0 - smoothstep(0.72, 0.88, shoreLineMask));
            float washNoiseA = auroraWaterNoise(coastP / 74.0 + vec2(shoreTime * 0.010, -shoreTime * 0.004));
            float washNoiseB = auroraWaterNoise(coastP / 138.0 + vec2(-shoreTime * 0.004, shoreTime * 0.003) + 41.0);
            float nearWash = shallowZone * smoothstep(0.43, 0.72, washNoiseA * 0.65 + washNoiseB * 0.35);
            float nearBreaker = smoothstep(0.18, 0.30, shoreLineMask) *
                (1.0 - smoothstep(0.47, 0.56, shoreLineMask)) *
                smoothstep(0.50, 0.76, washNoiseB);

            // Far families arrive across world space. Wind rotates them, while broad noise
            // bends/breaks them so they are parallel-ish rather than ruler-straight.
            vec2 windAxis = normalize(vec2(cos(auroraWindDirection), sin(auroraWindDirection)) + vec2(0.001));
            vec2 breakerAxis = normalize(vec2(-windAxis.y, windAxis.x));
            float incoming = dot(coastP, breakerAxis) / 128.0;
            float bend = (auroraWaterNoise(coastP / 520.0 + windAxis * shoreTime * 0.002) - 0.5) * 2.8;
            float frontPhase = incoming + bend - shoreTime * mix(0.18, 0.34, auroraWindStrength);
            float secondaryWave = 1.0 - smoothstep(0.10, 0.32, abs(fract(frontPhase / 5.8 + 0.18) - 0.5));
            float farWave = 1.0 - smoothstep(0.08, 0.28, abs(fract(frontPhase / 9.6 + 0.63) - 0.5));
            float outerWave = 1.0 - smoothstep(0.06, 0.24, abs(fract(frontPhase / 15.4 + 0.37) - 0.5));

            // Distance windows keep each incoming family in a different coastal zone.
            float secondaryZone = smoothstep(0.16, 0.23, shoreLineMask) * (1.0 - smoothstep(0.34, 0.43, shoreLineMask));
            float farZone = smoothstep(0.055, 0.105, shoreLineMask) * (1.0 - smoothstep(0.22, 0.30, shoreLineMask));
            float outerZone = smoothstep(0.006, 0.035, shoreLineMask) * (1.0 - smoothstep(0.13, 0.19, shoreLineMask));

            float longBreak = smoothstep(0.28, 0.72, auroraWaterNoise(coastP / 190.0 + windAxis * shoreTime * 0.004));
            float mediumBreak = smoothstep(0.34, 0.77, auroraWaterNoise(coastP / 105.0 - windAxis * shoreTime * 0.006 + 31.0));
            float nearBreak = smoothstep(0.40, 0.79, auroraWaterNoise(coastP / 58.0 + windAxis * shoreTime * 0.009 + 67.0));

            float secondaryFront = coastalGate * secondaryZone * secondaryWave * mediumBreak;
            float farFront = coastalGate * farZone * farWave * longBreak;
            float outerFront = coastalGate * outerZone * outerWave * longBreak;

            // Offshore fronts remain mostly surface deformation; whitening increases only
            // as a front enters shallower water and begins to break.
            float swellFront = secondaryFront * 0.60 + farFront * 0.48 + outerFront * 0.34;
            baseColor *= 1.0 + swellFront * 0.060;
            normals = normalize(normals + vec3(coastWarp * swellFront * 0.12, 0.0, coastWarp2 * swellFront * 0.12));

            float precursorFoam = coastalGate * clamp(auroraShoreFoam, 0.0, 1.7) *
                (nearWash * 0.28 * nearBreak +
                 nearBreaker * 0.25 * nearBreak +
                 secondaryFront * 0.20 +
                 farFront * 0.115 +
                 outerFront * 0.064);
            auroraFoam += precursorFoam;

        }
		// Energetic presets can form sparse whitecaps away from the coast.
		float openWater = 1.0 - smoothstep(0.02, 0.30, shoreLineMask);
        // Water 3.1: rare, very faint subsurface silhouettes. They are allowed in
        // sufficiently clear non-flat water, with Ocean 3.0 receiving the highest
        // chance. This stays procedural and intentionally reads as a passing shadow,
        // not a literal high-detail fish model.
        if (auroraUnderwaterSilhouettes != 0 && !waterType.isFlat && !auroraStormy && auroraWaterClarity > 0.42) {
            vec2 fishTravel = waterWorld + vec2(elapsedTime * 4.4, -elapsedTime * 1.7);
            float fishCellSize = auroraOcean3 ? 560.0 : 690.0;
            vec2 fishCell = floor(fishTravel / fishCellSize);
            vec2 fishUv = fract(fishTravel / fishCellSize) - 0.5;
            float fishSeed = auroraWaterHash(fishCell + 17.0);
            fishUv -= vec2(auroraWaterHash(fishCell + 29.0) - 0.5, auroraWaterHash(fishCell + 53.0) - 0.5) * 0.38;
            float angle = fishSeed * 6.2831853;
            mat2 fishRot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
            fishUv = fishRot * fishUv;
            float fishBody = 1.0 - smoothstep(0.046, 0.090, length(vec2(fishUv.x * 0.50, fishUv.y * 1.72)));
            float tailBand = (1.0 - smoothstep(0.015, 0.080, abs(fishUv.y))) *
                smoothstep(-0.235, -0.13, fishUv.x) * (1.0 - smoothstep(-0.13, -0.055, fishUv.x));
            float rareThreshold = auroraOcean3 ? 0.88 : 0.925;
            float fishRare = step(rareThreshold, auroraWaterHash(fishCell + 91.0));
            float shallowFade = 1.0 - smoothstep(0.22, 0.66, shoreLineMask);
            float fishShadow = clamp(max(fishBody, tailBand * 0.68) * fishRare * openWater * shallowFade, 0.0, 1.0);
            baseColor *= 1.0 - fishShadow * (auroraOcean3 ? 0.040 : 0.030) * clamp(auroraWaterClarity, 0.0, 1.20);
        }
		float whitecapNoise = auroraWaterNoise(waterWorld / 52.0 + vec2(elapsedTime * 0.025, -elapsedTime * 0.015));
		float whitecapFine = auroraWaterNoise(waterWorld / 27.0 + vec2(-elapsedTime * 0.018, elapsedTime * 0.023));
		float whitecapField = auroraWaveCrest * 0.70 + whitecapNoise * 0.21 + whitecapFine * 0.09;
		// 0.9: active coast carries a field of many small whitecaps instead of a few bright patches.
		float crestGate = smoothstep(0.58, 0.79, auroraWaveCrest);
        float whitecaps = smoothstep(0.58, 0.80, whitecapField) * crestGate * openWater *
            clamp((auroraWaterDynamics - 0.62) * 0.98, 0.0, 0.82);
        if (auroraOcean3) {
            // Fewer pin-point caps; favor coherent crests, collision froth and soft bubble fields.
            float coherentGate = smoothstep(0.68, 0.86, auroraWaveCrest);
            whitecaps *= coherentGate * 0.52;
            float oceanFoamTime = elapsedTime * 0.405;
            float bubbleField = smoothstep(0.62, 0.82, auroraWaterNoise(waterWorld / 34.0 + vec2(oceanFoamTime * 0.018, oceanFoamTime * -0.012)))
                * smoothstep(0.36, 0.82, auroraWaterNoise(waterWorld / 88.0 - vec2(oceanFoamTime * 0.007, 0.0)));
            float bubbleFieldB = smoothstep(0.70, 0.88, auroraWaterNoise(waterWorld / 19.0 + vec2(-oceanFoamTime * 0.021, oceanFoamTime * 0.016)));
            float streakCarrier = auroraWaterNoise(waterWorld / 54.0 + vec2(oceanFoamTime * 0.015, -oceanFoamTime * 0.010));
            float streakBreak = auroraWaterNoise(waterWorld / 21.0 + vec2(-oceanFoamTime * 0.009, oceanFoamTime * 0.013));
            float streaks = smoothstep(0.68, 0.88, streakCarrier) * smoothstep(0.42, 0.78, streakBreak);
            float collisionFoam = auroraCrossCollision * smoothstep(0.44, 0.74, auroraWaterNoise(waterWorld / 58.0 + oceanFoamTime * 0.006));
            float collisionFroth = pow(auroraCrossCollision, 1.35) * smoothstep(0.52, 0.84, auroraWaterNoise(waterWorld / 31.0 - oceanFoamTime * 0.009));
            auroraFoam += (bubbleField * 0.12 + bubbleFieldB * 0.045 + streaks * 0.085 + collisionFoam * 0.27 + collisionFroth * 0.20) * openWater;
        }
		auroraFoam += whitecaps;
		// Keep actual shore/breaker structure but cap the broad milky layer. The old
		// mix could make low-frequency foam read as a white cloud trapped under water.
		foamAmount = clamp(max(foamAmount, auroraFoam * (auroraOcean3 ? 0.86 : 0.78)), 0.0, 0.78);
		// Sea-foam is blue-grey and translucent. Directional glints remain a separate
		// path, so bright open-water reflection reads as reflection rather than foam.
		vec3 auroraFoamColor = vec3(0.42, 0.56, 0.64) *
			(ambientLightOut + max(lightOut, vec3(0.11)) + skyLightOut * 0.62);
		foamColor = mix(baseColor, auroraFoamColor, clamp(auroraFoam * 0.86, 0.0, 0.54));
	}
    baseColor = mix(baseColor, foamColor, foamAmount);
    vec3 specularComposite = mix(lightSpecularOut, vec3(0.0), foamAmount);
    float flatFresnel = (1.0 - dot(viewDir, vec3(0, -1, 0))) * 1.0;
    finalFresnel = max(finalFresnel, flatFresnel);
    finalFresnel -= finalFresnel * shadow * 0.2;
    baseColor += pointLightsSpecularOut + lightSpecularOut / 3;

    // Water 3.1 celestial highlight path. All non-flat Aurora water can now catch
    // a coherent sun/moon streak from the real wave normals; Ocean 3.0 simply gets
    // the longest, most energetic version.
    if (auroraEnabled != 0 && !waterType.isFlat && auroraWaterReflection > 0.0) {
        vec3 celestialReflect = reflect(-lightDir, normals);
        float alignment = max(dot(viewDir, celestialReflect), 0.0);
        float waterClock = fract(auroraTimeOfDay +
            (auroraDayCycleEnabled != 0 ? elapsedTime * mix(0.00002, 0.00055, auroraDayCycleSpeed) : 0.0));
        float waterSunHeight = sin((waterClock - 0.25) * 6.28318530718);
        float waterDaylight = smoothstep(-0.18, 0.12, waterSunHeight);
        float waterTwilight = exp(-pow(abs(waterSunHeight) * 3.3, 2.0));
        float glintGloss = auroraOcean3 ? mix(30.0, 86.0, waterDaylight) : mix(38.0, 108.0, waterDaylight);
        float longGlint = pow(alignment, glintGloss);
        vec2 waterWorld = IN.position.xz;
        float oceanGlintTime = elapsedTime * (auroraOcean3 ? 1.86 : 0.82);
        float glintBreakup = 0.40 + 0.60 * auroraWaterNoise(waterWorld / (auroraOcean3 ? 46.0 : 36.0) +
            vec2(oceanGlintTime * 0.024, -oceanGlintTime * 0.018));
        float fineGlint = smoothstep(0.46, 0.82, auroraWaterNoise(waterWorld / 14.0 +
            vec2(-oceanGlintTime * 0.036, oceanGlintTime * 0.025)));
        float glintStrength = longGlint * glintBreakup * (0.78 + 0.22 * fineGlint) *
            (1.0 - foamAmount * 0.78) * clamp(auroraWaterReflection, 0.0, 1.4);
        vec3 moonSilver = vec3(0.48, 0.60, 0.84);
        vec3 sunGold = mix(vec3(1.00, 0.78, 0.46), vec3(1.00, 0.90, 0.70), 1.0 - waterTwilight);
        float highlightStrength = auroraOcean3 ? 0.37 : 0.28;
        baseColor += mix(moonSilver * 0.17, sunGold * highlightStrength, waterDaylight) * glintStrength * inverseShadow;
    }

    float alpha = max(waterType.baseOpacity, max(foamAmount, max(finalFresnel, length(specularComposite / 3))));

    // Looking downward into calm non-flat water reveals more existing underwater terrain.
    // Fresnel, foam and authored minimum opacity continue to protect horizon views and special water.
    if (auroraEnabled != 0 && auroraWaterClarity > 0.0 && !waterType.isFlat) {
        float downwardView = smoothstep(0.10, 0.88, -viewDir.y);
        float clarity = auroraWaterClarity * downwardView * (1.0 - foamAmount);
        float clearTarget = mix(waterType.baseOpacity, 0.18, clarity);
        alpha = max(clearTarget, max(foamAmount, finalFresnel * mix(1.0, 0.68, clarity)));
    }

    if (waterType.isFlat) {
        baseColor = mix(waterType.depthColor, baseColor, alpha);
        alpha = 1;
    }

    return vec4(baseColor, alpha);
}

void sampleUnderwater(inout vec3 outputColor, WaterType waterType, float depth, float lightDotNormals) {
    // underwater terrain
    float lowestColorLevel = 500;
    float midColorLevel = 150;
    float surfaceLevel = IN.position.y - depth; // e.g. -1600

    if (depth < midColorLevel) {
        outputColor *= mix(vec3(1), waterType.depthColor, translateRange(0, midColorLevel, depth));
    } else if (depth < lowestColorLevel) {
        outputColor *= mix(waterType.depthColor, vec3(0), translateRange(midColorLevel, lowestColorLevel, depth));
    } else {
        outputColor = vec3(0);
    }

    // Aurora shallow-water clarity: preserve more color near the surface and shift
    // gently toward aqua with depth instead of dropping immediately toward black.
    if (auroraEnabled != 0) {
        float shallow = 1.0 - smoothstep(90.0, 420.0, depth);
        float depthHaze = smoothstep(110.0, 520.0, depth);
        vec3 shallowTint = vec3(0.82, 0.97, 0.96);
        vec3 deepTint = vec3(0.34, 0.52, 0.58);
        outputColor = mix(outputColor, outputColor * shallowTint, shallow * 0.24);
        outputColor = mix(outputColor, outputColor * deepTint, depthHaze * 0.22);
    }

    if (underwaterCaustics) {
        const float scale = 1.75;
        const float maxCausticsDepth = 128 * 4;

        vec2 causticsUv = worldUvs(scale);

        float depthMultiplier = (IN.position.y - surfaceLevel - maxCausticsDepth) / -maxCausticsDepth;
        depthMultiplier *= depthMultiplier;

        causticsUv *= .75;

        const ivec2 direction = ivec2(1, -2);
        vec2 flow1 = causticsUv + animationFrame(17) * direction;
        vec2 flow2 = causticsUv * 1.5 + animationFrame(23) * -direction;
        vec3 caustics = sampleCaustics(flow1, flow2, .005);

        vec3 causticsColor = underwaterCausticsColor * underwaterCausticsStrength;
        outputColor.rgb *= 1 + caustics * causticsColor * depthMultiplier * lightDotNormals * lightStrength;
    }
}
