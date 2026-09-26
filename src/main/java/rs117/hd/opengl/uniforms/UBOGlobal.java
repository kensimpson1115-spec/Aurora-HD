package rs117.hd.opengl.uniforms;

import rs117.hd.utils.buffer.GLBuffer;

import static org.lwjgl.opengl.GL33C.*;

public class UBOGlobal extends UniformBuffer<GLBuffer> {
	public UBOGlobal() {
		super(GL_DYNAMIC_DRAW);
	}

	@Override
	public void initialize() {
		super.initialize();
	}

	public Property expandedMapLoadingChunks = addProperty(PropertyType.Int, "expandedMapLoadingChunks");
	public Property drawDistance = addProperty(PropertyType.Float, "drawDistance");
	public Property auroraEnabled = addProperty(PropertyType.Int, "auroraEnabled");
	public Property auroraTerrainDetail = addProperty(PropertyType.Float, "auroraTerrainDetail");
	public Property auroraWaterDynamics = addProperty(PropertyType.Float, "auroraWaterDynamics");
	public Property auroraWaterPreset = addProperty(PropertyType.Int, "auroraWaterPreset");
	public Property auroraColorGrade = addProperty(PropertyType.Float, "auroraColorGrade");
	public Property auroraAtmosphereEnabled = addProperty(PropertyType.Int, "auroraAtmosphereEnabled");
	public Property auroraHaze = addProperty(PropertyType.Float, "auroraHaze");
	public Property auroraCloudShadows = addProperty(PropertyType.Float, "auroraCloudShadows");
	public Property auroraDryDust = addProperty(PropertyType.Float, "auroraDryDust");
	public Property auroraMaterialDepth = addProperty(PropertyType.Float, "auroraMaterialDepth");
	public Property auroraWaterClarity = addProperty(PropertyType.Float, "auroraWaterClarity");
	public Property auroraWaterReflection = addProperty(PropertyType.Float, "auroraWaterReflection");
	public Property auroraShoreFoam = addProperty(PropertyType.Float, "auroraShoreFoam");
	public Property auroraWeatherEnabled = addProperty(PropertyType.Int, "auroraWeatherEnabled");
	public Property auroraCloudCover = addProperty(PropertyType.Float, "auroraCloudCover");
	public Property auroraDayCycleEnabled = addProperty(PropertyType.Int, "auroraDayCycleEnabled");
	public Property auroraDayCycleSpeed = addProperty(PropertyType.Float, "auroraDayCycleSpeed");
	public Property auroraSkyEnabled = addProperty(PropertyType.Int, "auroraSkyEnabled");
	public Property auroraTimeOfDay = addProperty(PropertyType.Float, "auroraTimeOfDay");
	public Property auroraCelestialDebug = addProperty(PropertyType.Int, "auroraCelestialDebug");
	public Property auroraLodDebug = addProperty(PropertyType.Int, "auroraLodDebug");
	public Property auroraRenderMoon = addProperty(PropertyType.Int, "auroraRenderMoon");
	public Property auroraRenderStars = addProperty(PropertyType.Int, "auroraRenderStars");
	public Property auroraMaterialResponse = addProperty(PropertyType.Int, "auroraMaterialResponse");
	public Property auroraCloudLightCoupling = addProperty(PropertyType.Int, "auroraCloudLightCoupling");
	public Property auroraVisibleClouds = addProperty(PropertyType.Int, "auroraVisibleClouds");
	public Property auroraCloudDepth = addProperty(PropertyType.Float, "auroraCloudDepth");
	public Property auroraWetness = addProperty(PropertyType.Float, "auroraWetness");
	public Property auroraWindStrength = addProperty(PropertyType.Float, "auroraWindStrength");
	public Property auroraWindDirection = addProperty(PropertyType.Float, "auroraWindDirection");
	public Property auroraCloudParallax = addProperty(PropertyType.Int, "auroraCloudParallax");
	public Property auroraVegetationWind = addProperty(PropertyType.Float, "auroraVegetationWind");
	public Property auroraWeatherTransitions = addProperty(PropertyType.Int, "auroraWeatherTransitions");
	public Property auroraSkyCloudAmount = addProperty(PropertyType.Float, "auroraSkyCloudAmount");
	public Property auroraRain = addProperty(PropertyType.Float, "auroraRain");
	public Property auroraSnow = addProperty(PropertyType.Float, "auroraSnow");
	public Property auroraWorldDetailPass = addProperty(PropertyType.Int, "auroraWorldDetailPass");
	public Property auroraUnderwaterSilhouettes = addProperty(PropertyType.Int, "auroraUnderwaterSilhouettes");
	public Property auroraDetailDistance = addProperty(PropertyType.Float, "auroraDetailDistance");
	public Property auroraWeatherWorldOffset = addProperty(PropertyType.FVec2, "auroraWeatherWorldOffset");

	public Property colorBlindnessIntensity = addProperty(PropertyType.Float, "colorBlindnessIntensity");
	public Property gammaCorrection = addProperty(PropertyType.Float, "gammaCorrection");
	public Property saturation = addProperty(PropertyType.Float, "saturation");
	public Property contrast = addProperty(PropertyType.Float, "contrast");
	public Property colorFilterPrevious = addProperty(PropertyType.Int, "colorFilterPrevious");
	public Property colorFilter = addProperty(PropertyType.Int, "colorFilter");
	public Property colorFilterFade = addProperty(PropertyType.Float, "colorFilterFade");

	public Property sceneResolution = addProperty(PropertyType.IVec2, "sceneResolution");
	public Property tiledLightingResolution = addProperty(PropertyType.IVec2, "tiledLightingResolution");

	public Property ambientColor = addProperty(PropertyType.FVec3, "ambientColor");
	public Property ambientStrength = addProperty(PropertyType.Float, "ambientStrength");
	public Property lightColor = addProperty(PropertyType.FVec3, "lightColor");
	public Property lightStrength = addProperty(PropertyType.Float, "lightStrength");
	public Property underglowColor = addProperty(PropertyType.FVec3, "underglowColor");
	public Property underglowStrength = addProperty(PropertyType.Float, "underglowStrength");

	public Property useFog = addProperty(PropertyType.Int, "useFog");
	public Property fogDepth = addProperty(PropertyType.Float, "fogDepth");
	public Property fogColor = addProperty(PropertyType.FVec3, "fogColor");
	public Property groundFogStart = addProperty(PropertyType.Float, "groundFogStart");
	public Property groundFogEnd = addProperty(PropertyType.Float, "groundFogEnd");
	public Property groundFogOpacity = addProperty(PropertyType.Float, "groundFogOpacity");

	public Property waterColorLight = addProperty(PropertyType.FVec3, "waterColorLight");
	public Property waterColorMid = addProperty(PropertyType.FVec3, "waterColorMid");
	public Property waterColorDark = addProperty(PropertyType.FVec3, "waterColorDark");

	public Property underwaterEnvironment = addProperty(PropertyType.Int, "underwaterEnvironment");
	public Property underwaterCaustics = addProperty(PropertyType.Int, "underwaterCaustics");
	public Property underwaterCausticsColor = addProperty(PropertyType.FVec3, "underwaterCausticsColor");
	public Property underwaterCausticsStrength = addProperty(PropertyType.Float, "underwaterCausticsStrength");

	public Property lightDir = addProperty(PropertyType.FVec3, "lightDir");

	public Property pointLightsCount = addProperty(PropertyType.Int, "pointLightsCount");

	public Property cameraPos = addProperty(PropertyType.FVec3, "cameraPos");
	public Property viewMatrix = addProperty(PropertyType.Mat4, "viewMatrix");
	public Property projectionMatrix = addProperty(PropertyType.Mat4, "projectionMatrix");
	public Property invProjectionMatrix = addProperty(PropertyType.Mat4, "invProjectionMatrix");
	public Property lightProjectionMatrix = addProperty(PropertyType.Mat4, "lightProjectionMatrix");

	public Property lightningBrightness = addProperty(PropertyType.Float, "lightningBrightness");
	public Property elapsedTime = addProperty(PropertyType.Float, "elapsedTime");
}
