package rs117.hd.config;

/**
 * Aurora's coordinated performance profiles.
 *
 * The enum constant names are intentionally retained for config compatibility:
 * SUPERB is displayed as "Very high" and ULTRA is displayed as "Superb".
 */
public enum AuroraGraphicsPreset
{
	VERY_LOW(
		"Very low",
		TextureResolution.RES_128,
		GroundBlending.TEXTURES_ONLY,
		ShadowMode.OFF,
		ShadowResolution.RES_1024,
		DynamicLights.NONE,
		AuroraAtmosphereStrength.OFF,
		AuroraWaterPreset.CALM_CLEAR,
		AntiAliasingMode.DISABLED, 2,
		28, 28, 28, 65, 0, 0,
		48, 32, 1,
		true, true, false, false, false, false, false, false, false),

	LOW(
		"Low",
		TextureResolution.RES_256,
		GroundBlending.TEXTURES_ONLY,
		ShadowMode.FAST,
		ShadowResolution.RES_1024,
		DynamicLights.FEW,
		AuroraAtmosphereStrength.LOW,
		AuroraWaterPreset.CALM_CLEAR,
		AntiAliasingMode.DISABLED, 4,
		45, 45, 45, 82, 28, 8,
		72, 48, 2,
		true, true, true, true, false, true, true, true, false),

	MEDIUM(
		"Medium",
		TextureResolution.RES_512,
		GroundBlending.ON,
		ShadowMode.FAST,
		ShadowResolution.RES_2048,
		DynamicLights.SOME,
		AuroraAtmosphereStrength.MEDIUM,
		AuroraWaterPreset.NATURAL,
		AntiAliasingMode.DISABLED, 8,
		62, 68, 68, 94, 62, 18,
		112, 80, 3,
		true, true, true, true, true, true, true, true, true),

	HIGH(
		"High",
		TextureResolution.RES_512,
		GroundBlending.ON,
		ShadowMode.DETAILED,
		ShadowResolution.RES_4096,
		DynamicLights.SOME,
		AuroraAtmosphereStrength.MEDIUM,
		AuroraWaterPreset.NATURAL,
		AntiAliasingMode.DISABLED, 16,
		76, 86, 86, 100, 86, 28,
		160, 112, 4,
		true, true, true, true, true, true, true, true, true),

	SUPERB(
		"Very high",
		TextureResolution.RES_1024,
		GroundBlending.ON,
		ShadowMode.DETAILED,
		ShadowResolution.RES_4096,
		DynamicLights.SOME,
		AuroraAtmosphereStrength.HIGH,
		AuroraWaterPreset.COASTAL,
		AntiAliasingMode.DISABLED, 16,
		90, 100, 100, 100, 100, 40,
		184, 160, 5,
		true, true, true, true, true, true, true, true, true),

	ULTRA(
		"Superb",
		TextureResolution.RES_1024,
		GroundBlending.ON,
		ShadowMode.DETAILED,
		ShadowResolution.RES_8192,
		DynamicLights.MANY,
		AuroraAtmosphereStrength.HIGH,
		AuroraWaterPreset.OCEAN_3,
		AntiAliasingMode.DISABLED, 16,
		100, 100, 100, 100, 100, 48,
		184, 184, 5,
		true, true, true, true, true, true, true, true, true);

	private final String name;
	public final TextureResolution textureResolution;
	public final GroundBlending groundBlending;
	public final ShadowMode shadowMode;
	public final ShadowResolution shadowResolution;
	public final DynamicLights dynamicLights;
	public final AuroraAtmosphereStrength atmosphereStrength;
	public final AuroraWaterPreset waterPreset;
	public final AntiAliasingMode antiAliasingMode;
	public final int anisotropicFilteringLevel;
	public final int waterStrength;
	public final int terrainDetail;
	public final int materialDepth;
	public final int colorGrade;
	public final int cloudShadows;
	public final int vegetationWind;
	public final int drawDistance;
	public final int detailDistance;
	/** True live RuneLite scene expansion. Hard-limited to five chunks by the 184x184 extended scene. */
	public final int expandedMapLoadingChunks;
	public final boolean modelTextures;
	public final boolean groundTextures;
	public final boolean windDisplacement;
	public final boolean sky;
	public final boolean visibleClouds;
	public final boolean materialResponse;
	public final boolean cloudLightCoupling;
	public final boolean normalMapping;
	public final boolean parallaxOcclusionMapping;

	AuroraGraphicsPreset(
		String name,
		TextureResolution textureResolution,
		GroundBlending groundBlending,
		ShadowMode shadowMode,
		ShadowResolution shadowResolution,
		DynamicLights dynamicLights,
		AuroraAtmosphereStrength atmosphereStrength,
		AuroraWaterPreset waterPreset,
		AntiAliasingMode antiAliasingMode,
		int anisotropicFilteringLevel,
		int waterStrength,
		int terrainDetail,
		int materialDepth,
		int colorGrade,
		int cloudShadows,
		int vegetationWind,
		int drawDistance,
		int detailDistance,
		int expandedMapLoadingChunks,
		boolean modelTextures,
		boolean groundTextures,
		boolean windDisplacement,
		boolean sky,
		boolean visibleClouds,
		boolean materialResponse,
		boolean cloudLightCoupling,
		boolean normalMapping,
		boolean parallaxOcclusionMapping)
	{
		this.name = name;
		this.textureResolution = textureResolution;
		this.groundBlending = groundBlending;
		this.shadowMode = shadowMode;
		this.shadowResolution = shadowResolution;
		this.dynamicLights = dynamicLights;
		this.atmosphereStrength = atmosphereStrength;
		this.waterPreset = waterPreset;
		this.antiAliasingMode = antiAliasingMode;
		this.anisotropicFilteringLevel = anisotropicFilteringLevel;
		this.waterStrength = waterStrength;
		this.terrainDetail = terrainDetail;
		this.materialDepth = materialDepth;
		this.colorGrade = colorGrade;
		this.cloudShadows = cloudShadows;
		this.vegetationWind = vegetationWind;
		this.drawDistance = drawDistance;
		this.detailDistance = detailDistance;
		this.expandedMapLoadingChunks = Math.min(5, expandedMapLoadingChunks);
		this.modelTextures = modelTextures;
		this.groundTextures = groundTextures;
		this.windDisplacement = windDisplacement;
		this.sky = sky;
		this.visibleClouds = visibleClouds;
		this.materialResponse = materialResponse;
		this.cloudLightCoupling = cloudLightCoupling;
		this.normalMapping = normalMapping;
		this.parallaxOcclusionMapping = parallaxOcclusionMapping;
	}

	@Override
	public String toString()
	{
		return name;
	}
}
