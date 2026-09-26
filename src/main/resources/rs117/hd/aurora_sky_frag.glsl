#version 330

#include <uniforms/global.glsl>

in vec3 vSkyDirection;
in vec2 vSkyUv;
out vec4 FragColor;

const float AURORA_PI = 3.14159265359;

float skyHash(vec2 p)
{
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float skyNoise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(skyHash(i), skyHash(i + vec2(1, 0)), f.x),
		mix(skyHash(i + vec2(0, 1)), skyHash(i + vec2(1, 1)), f.x), f.y);
}

float skyFbm(vec2 p)
{
	float value = 0.0;
	float amplitude = 0.52;
	for (int i = 0; i < 5; ++i) {
		value += skyNoise(p) * amplitude;
		p = p * 2.03 + vec2(13.7, -9.2);
		amplitude *= 0.49;
	}
	return value;
}

float auroraTime()
{
	float automaticAdvance = elapsedTime * mix(0.00002, 0.00055, auroraDayCycleSpeed);
	return fract(auroraTimeOfDay + (auroraDayCycleEnabled != 0 ? automaticAdvance : 0.0));
}

void main()
{
	vec3 direction = normalize(vSkyDirection);
	// RuneLite local/world coordinates use Z as vertical.
	float altitude = clamp(-direction.y, 0.0, 1.0);
	float horizon = pow(1.0 - altitude, 2.05);
	float time = auroraTime();
	float solarAngle = (time - 0.25) * 2.0 * AURORA_PI;
	float sunHeight = sin(solarAngle);
	float daylight = smoothstep(-0.22, 0.10, sunHeight);
	float night = 1.0 - smoothstep(-0.20, 0.02, sunHeight);
	float lowSun = exp(-pow(sunHeight * 4.0, 2.0));
	float belowHorizon = smoothstep(-0.34, 0.02, sunHeight) * (1.0 - smoothstep(0.03, 0.30, sunHeight));
	float warmBand = max(lowSun, belowHorizon * 0.82);

	// 0.12: deep black/navy night restored while preserving a faint readable horizon.
	vec3 nightZenith = vec3(0.008, 0.012, 0.028);
	vec3 nightHorizon = vec3(0.018, 0.030, 0.062);
	vec3 dayZenith = vec3(0.075, 0.285, 0.665);
	vec3 dayHorizon = vec3(0.405, 0.675, 0.925);
	vec3 zenith = mix(nightZenith, dayZenith, daylight);
	vec3 horizonColor = mix(nightHorizon, dayHorizon, daylight);
	vec3 violet = vec3(0.33, 0.20, 0.43);
	vec3 rose = vec3(0.86, 0.30, 0.38);
	vec3 orange = vec3(1.00, 0.43, 0.16);
	vec3 gold = vec3(1.00, 0.70, 0.32);
	float violetStage = belowHorizon * (1.0 - smoothstep(-0.12, 0.04, sunHeight));
	float roseStage = exp(-pow((sunHeight + 0.055) * 7.0, 2.0));
	float goldStage = exp(-pow((sunHeight - 0.055) * 6.0, 2.0));
	horizonColor = mix(horizonColor, violet, violetStage * 0.46);
	horizonColor = mix(horizonColor, rose, roseStage * 0.48);
	horizonColor = mix(horizonColor, orange, warmBand * 0.38);
	horizonColor = mix(horizonColor, gold, goldStage * 0.34);
	zenith = mix(zenith, vec3(0.22, 0.18, 0.38), violetStage * 0.20);
	vec3 sky = mix(zenith, horizonColor, horizon);

	float cameraYaw = atan(viewMatrix[0][2], viewMatrix[0][0]) / (2.0 * AURORA_PI);
	float cameraPitch = asin(clamp(viewMatrix[1][2], -1.0, 1.0)) / AURORA_PI;

	// 0.10: true spatial dawn/dusk gradient. Warmth is strongest near the
	// solar horizon instead of tinting the entire sky uniformly.
	vec3 sunDirection = normalize(vec3(cos(solarAngle) * 0.78, -sunHeight, sin(solarAngle) * 0.62));
	float sunFacingHorizon = pow(max(dot(normalize(vec3(direction.x, 0.0, direction.z)), normalize(vec3(sunDirection.x, 0.0, sunDirection.z))), 0.0), 3.0);
	float horizonBand = pow(1.0 - altitude, 3.2);
	float spatialTwilight = horizonBand * sunFacingHorizon * clamp(warmBand * 1.45, 0.0, 1.0);
	sky = mix(sky, vec3(0.48, 0.20, 0.48), spatialTwilight * violetStage * 0.48);
	sky = mix(sky, vec3(0.96, 0.29, 0.30), spatialTwilight * roseStage * 0.68);
	sky = mix(sky, vec3(1.00, 0.49, 0.14), spatialTwilight * 0.62);
	sky = mix(sky, vec3(1.00, 0.76, 0.38), spatialTwilight * goldStage * 0.52);
	float sunDisc = smoothstep(0.99920, 0.99978, dot(direction, sunDirection));
	float sunGlow = pow(max(dot(direction, sunDirection), 0.0), 64.0);
	vec3 sunColor = mix(vec3(1.0, 0.34, 0.12), vec3(1.0, 0.93, 0.72), smoothstep(0.02, 0.55, sunHeight));
	sky += sunColor * (sunDisc * 0.32 + sunGlow * 0.16) * smoothstep(-0.08, 0.05, sunHeight);

	// Aurora 0.17 Sky Visibility Repair.
	// 0.14 proved screen UV is unquestionably the live visible sky surface. 0.15/0.16
	// then made celestial visibility depend entirely on a reconstructed world ray. That
	// was architecturally cleaner, but it let coordinate/hemisphere errors make every
	// object disappear. 0.17 uses the proven screen surface with camera-orientation
	// offsets for stars/clouds, while retaining world-direction lighting separately.
	float sunClock = clamp((time - 0.25) / 0.50, 0.0, 1.0);
	float sunArc = sunClock * AURORA_PI;
	vec2 sunCenter = vec2(
		fract(0.50 + cos(sunArc) * 0.40 - cameraYaw + 1.0),
		0.41 + sin(sunArc) * 0.59 - cameraPitch * 0.13
	);
	vec2 sunDelta = vSkyUv - sunCenter;
	sunDelta.x *= sceneResolution.x / max(float(sceneResolution.y), 1.0);
	float sunDistance = length(sunDelta);
	float sunObjectDisc = 1.0 - smoothstep(0.018, 0.024, sunDistance);
	float sunObjectCore = 1.0 - smoothstep(0.012, 0.017, sunDistance);
	float sunObjectGlow = 1.0 - smoothstep(0.024, 0.070, sunDistance);
	float sunObjectVisibility = smoothstep(-0.08, 0.06, sunHeight);
	sky += sunColor * (sunObjectDisc * 1.75 + sunObjectCore * 0.42 + sunObjectGlow * 0.17) * sunObjectVisibility;

	// High moon arc. The visible-disc path is guaranteed to intersect the proven sky
	// surface; camera yaw shifts the apparent azimuth instead of pinning it to the screen.
	float moonClock = fract(time + 0.50);
	float moonArc = moonClock * AURORA_PI;
	vec2 moonCenter = vec2(
		fract(0.50 + cos(moonArc) * 0.40 - cameraYaw + 1.0),
		0.41 + sin(moonArc) * 0.59 - cameraPitch * 0.13
	);
	vec2 moonDelta = vSkyUv - moonCenter;
	moonDelta.x *= sceneResolution.x / max(float(sceneResolution.y), 1.0);
	float moonDistance = length(moonDelta);
	float moonDisc = 1.0 - smoothstep(0.025, 0.029, moonDistance);
	float moonCore = 1.0 - smoothstep(0.019, 0.025, moonDistance);
	float moonGlow = 1.0 - smoothstep(0.030, 0.052, moonDistance);
	// Moon 3.0: deliberately chunky OSRS-scale surface markings rather than
	// high-frequency photographic noise. The few large maria remain readable at game scale.
	vec2 lunarUv = moonDelta / 0.027;
	float mariaA = 1.0 - smoothstep(0.22, 0.34, length(lunarUv - vec2(-0.22, 0.18)));
	float mariaB = 1.0 - smoothstep(0.16, 0.27, length(lunarUv - vec2(0.26, 0.06)));
	float mariaC = 1.0 - smoothstep(0.12, 0.22, length(lunarUv - vec2(0.03, -0.27)));
	float craterA = 1.0 - smoothstep(0.070, 0.115, length(lunarUv - vec2(-0.05, 0.36)));
	float craterB = 1.0 - smoothstep(0.055, 0.095, length(lunarUv - vec2(0.35, -0.20)));
	float softMottle = skyFbm(lunarUv * 2.4 + vec2(13.0, -7.0));
	float lunarMottle = 0.94 - mariaA * 0.18 - mariaB * 0.14 - mariaC * 0.12
		- craterA * 0.10 - craterB * 0.08 + (softMottle - 0.5) * 0.08;
	float phase = 0.5 + 0.5 * sin(elapsedTime * 0.003);
	float terminator = smoothstep(-0.014, 0.010, moonDelta.x + (phase - 0.5) * 0.022);
	float moonIllumination = mix(0.34, 1.0, terminator);
	if (auroraRenderMoon != 0 && night > 0.05)
		sky += vec3(0.78, 0.84, 0.96) * (moonDisc * 1.18 * lunarMottle * moonIllumination + moonCore * 0.16 + moonGlow * 0.045) * night;

	// Camera-stabilized star atlas on the proven sky surface. Much smaller and denser
	// than 0.14, with most stars faint and only rare hero stars.
	vec2 starUv = vSkyUv + vec2(cameraYaw, -cameraPitch * 0.34);
	vec2 starGrid = vec2(235.0, 132.0);
	vec2 starCell = floor(starUv * starGrid);
	vec2 starLocal = fract(starUv * starGrid) - 0.5;
	float starSeed = skyHash(starCell + 17.0);
	float starExists = step(0.925, starSeed);
	vec2 starOffset = vec2(skyHash(starCell + 31.0), skyHash(starCell + 47.0)) - 0.5;
	starLocal -= starOffset * 0.43;
	float brightSeed = skyHash(starCell + 71.3);
	float starRadius = mix(0.060, 0.128, brightSeed);
	float starShape = 1.0 - smoothstep(starRadius, starRadius + 0.045, length(starLocal));
	float starBrightness = mix(0.11, 0.54, brightSeed) + step(0.994, brightSeed) * 0.62;
	float twinkleMask = step(0.82, skyHash(starCell + 101.0));
	float twinkle = mix(1.0, 0.93 + 0.07 * sin(elapsedTime * mix(0.5, 1.3, brightSeed) + starSeed * 37.0), twinkleMask);
	float starVisibility = smoothstep(0.24, 0.46, vSkyUv.y) * smoothstep(0.12, 0.70, night);
	vec3 starTint = mix(vec3(0.72, 0.83, 1.0), vec3(1.0, 0.92, 0.79), skyHash(starCell + 9.3));
	if (auroraRenderStars != 0)
		sky += starTint * starExists * starShape * starBrightness * twinkle * starVisibility;

	// Cloudscape 2.0. Screen-space projection is intentional here: the previous world-
	// projected cloud plane was invisible on the live client. Camera yaw/pitch offsets
	// stabilize the field while wind moves independent macro/detail layers.
	if (auroraVisibleClouds != 0 && auroraCloudCover > 0.01) {
		float cover = clamp(auroraSkyCloudAmount, 0.0, 1.0);
		float depthControl = clamp(auroraCloudDepth, 0.0, 1.0);
		vec2 skyPlane = vec2(vSkyUv.x * 2.35 + cameraYaw * 1.8, vSkyUv.y * 1.55 - cameraPitch * 0.55);
		vec2 windDir = vec2(cos(auroraWindDirection), sin(auroraWindDirection));
		vec2 wind = windDir * elapsedTime * mix(0.0030, 0.0100, auroraWindStrength);
		// Cloudscape 2.5: altitude-separated projected sheets. Camera motion changes
		// each layer by a different amount, creating parallax/depth rather than one painted mask.
		float parallax = auroraCloudParallax != 0 ? 1.0 : 0.0;
		vec2 cameraDrift = vec2(cameraYaw, -cameraPitch);
		vec2 lowPlane = skyPlane + cameraDrift * 0.34 * parallax;
		vec2 midPlane = skyPlane + cameraDrift * 0.17 * parallax;
		vec2 highPlane = skyPlane + cameraDrift * 0.055 * parallax;
		float broad = skyFbm(lowPlane * 0.88 + wind);
		float body = skyFbm(midPlane * 1.85 + wind * 1.28 + 17.0);
		float erosion = skyFbm(highPlane * 4.20 - wind * 0.46 - 31.0);
		float underside = skyFbm(lowPlane * 1.28 + wind * 0.72 + 91.0);
		float field = broad * 0.58 + body * 0.34 + erosion * 0.08;
		float threshold = mix(0.64, 0.29, cover);
		float density = smoothstep(threshold, threshold + mix(0.13, 0.050, depthControl), field);
		density *= smoothstep(0.16, 0.34, vSkyUv.y);
		float lowerShade = mix(1.0, 0.50, density * depthControl * (0.72 + underside * 0.36));
		float edge = smoothstep(0.02, 0.22, density) * (1.0 - smoothstep(0.55, 0.96, density));
		float billowLight = smoothstep(0.48, 0.86, body) * (1.0 - smoothstep(0.70, 0.96, erosion));
		vec3 nightCloud = vec3(0.050, 0.065, 0.115);
		vec3 dayCloud = mix(vec3(0.74, 0.78, 0.82), vec3(0.94, 0.96, 0.98), billowLight) * lowerShade;
		vec3 cloudColor = mix(nightCloud, dayCloud, daylight);
		cloudColor += vec3(1.0, 0.68, 0.40) * edge * warmBand * daylight * 0.44;
		float alpha = density * mix(0.66, 0.96, depthControl);
		sky = mix(sky, cloudColor, clamp(alpha, 0.0, 0.94));

		// Separate high cirrus sheet: elongated, faint, faster and much less opaque.
		vec2 cirrusUv = vec2(skyPlane.x * 0.68, skyPlane.y * 2.65) + vec2(-wind.x * 0.42, wind.y * 0.18) + 63.0;
		float cirrusField = skyFbm(cirrusUv);
		float cirrus = smoothstep(mix(0.82, 0.59, cover), mix(0.92, 0.72, cover), cirrusField);
		cirrus *= smoothstep(0.34, 0.62, vSkyUv.y) * 0.25;
		vec3 cirrusColor = mix(vec3(0.08, 0.10, 0.16), vec3(0.91, 0.93, 0.96), daylight);
		sky = mix(sky, cirrusColor, cirrus);
	}


	// Aurora 0.13 diagnostic path. This is intentionally rendered after clouds:
	// if these markers are visible, the sky/celestial framebuffer path is proven.
	if (auroraCelestialDebug != 0) {
		// Full-frame diagnostic tint + fixed markers. If this does not appear, the
		// running client is not using this Aurora sky program/config revision.
		sky = mix(sky, vec3(0.34, 0.02, 0.42), 0.38);
		float fixedMoon = 1.0 - smoothstep(0.070, 0.082, length(vSkyUv - vec2(0.72, 0.72)));
		sky = mix(sky, vec3(1.0, 0.10, 0.82), fixedMoon);
		vec2 dbg = fract(vSkyUv * vec2(18.0, 10.0)) - 0.5;
		float dbgStar = 1.0 - smoothstep(0.06, 0.12, length(dbg));
		sky += vec3(0.05, 1.0, 1.0) * dbgStar * 1.4;
	}


	// Aurora 0.55.4 Weather 2.0 sky precipitation. Rain is sparse, layered and
	// slower with mild wind slant; Snow deliberately retains the proven 0.55.3 look.
	if (auroraWeatherEnabled != 0 && (auroraRain > 0.001 || auroraSnow > 0.001)) {
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
				float cellSeed = skyHash(vec2(column * 0.83 + lf * 17.0, row * 1.37 + lf * 29.0));
				float occupancySeed = skyHash(vec2(column * 1.31 + 7.0, row * 1.73 + lf * 11.0));
				float occupancy = step(mix(0.50, 0.24, storm), occupancySeed);
				float speed = baseSpeed * mix(0.80, 1.18, cellSeed);
				float travelX = fp.x + rainDir.x * elapsedTime * speed + cellSeed * spacing * 0.62 + lf * 97.0;
				float localX = abs(fract(travelX / spacing) - (0.22 + skyHash(vec2(column + 19.0, row + 37.0)) * 0.56));
				float fall = fract((fp.y + elapsedTime * speed + cellSeed * fallSpan * 1.83) / fallSpan);
				float streakLen = mix(0.10, 0.23, depthLayer) * mix(0.86, 1.18, screenDepth);
				float thin = 1.0 - smoothstep(0.010, mix(0.026, 0.046, screenDepth), localX);
				float streak = occupancy * thin * smoothstep(0.08, 0.19, fall) *
					(1.0 - smoothstep(0.19 + streakLen, 0.26 + streakLen, fall));
				rainMask += streak * mix(0.26, 0.70, depthLayer);
			}
			rainMask = clamp(rainMask, 0.0, 1.0);
			sky = mix(sky, vec3(0.68, 0.78, 0.88), rainMask * auroraRain * mix(0.105, 0.18, storm));

			// Murky storm sky and occasional inexpensive double-flash lightning.
			sky = mix(sky, vec3(0.055, 0.065, 0.085), storm * 0.58);
			float stormBucket = floor(elapsedTime / 8.0);
			float stormSeed = skyHash(vec2(stormBucket, 91.7));
			float stormPhase = fract(elapsedTime / 8.0);
			float flashA = exp(-pow((stormPhase - 0.10) / 0.018, 2.0));
			float flashB = 0.52 * exp(-pow((stormPhase - 0.145) / 0.028, 2.0));
			float auroraLightning = storm * step(0.80, stormSeed) * clamp(flashA + flashB, 0.0, 1.0);
			sky += vec3(0.62, 0.69, 0.82) * auroraLightning * 0.78;
		}
		if (auroraSnow > 0.001) {
			vec2 drift = vec2(sin(elapsedTime * 0.55) * 22.0, elapsedTime * 34.0);
			vec2 sp = (fp + drift) / 18.0;
			vec2 cell = floor(sp);
			vec2 local = fract(sp) - vec2(skyHash(cell + 11.0), skyHash(cell + 37.0));
			float flake = 1.0 - smoothstep(0.035, 0.13, length(local));
			sky = mix(sky, vec3(0.95, 0.98, 1.0), flake * auroraSnow * 0.38);
		}
	}

	// Lightweight filmic/HDR shoulder: retain bright celestial highlights without
	// hard clipping the rest of the atmosphere.
	sky = max(sky, vec3(0.0));
	vec3 mappedSky = sky * (2.20 * sky + 0.05) / (sky * (2.05 * sky + 0.55) + 0.14);
	mappedSky = clamp(mappedSky, 0.0, 1.0);
	FragColor = vec4(pow(mappedSky, vec3(gammaCorrection)), 1.0);
}
