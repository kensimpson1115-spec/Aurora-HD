#pragma once

#include <utils/constants.glsl>

layout(std140) uniform UBOGlobal {
    int expandedMapLoadingChunks;
    float drawDistance;
	int auroraEnabled;
	float auroraTerrainDetail;
	float auroraWaterDynamics;
	int auroraWaterPreset;
	float auroraColorGrade;
	int auroraAtmosphereEnabled;
	float auroraHaze;
	float auroraCloudShadows;
	float auroraDryDust;
	float auroraMaterialDepth;
	float auroraWaterClarity;
	float auroraWaterReflection;
	float auroraShoreFoam;
	int auroraWeatherEnabled;
	float auroraCloudCover;
	int auroraDayCycleEnabled;
	float auroraDayCycleSpeed;
	int auroraSkyEnabled;
	float auroraTimeOfDay;
	int auroraCelestialDebug;
	int auroraLodDebug;
	int auroraRenderMoon;
	int auroraRenderStars;
	int auroraMaterialResponse;
	int auroraCloudLightCoupling;
	int auroraVisibleClouds;
	float auroraCloudDepth;
	float auroraWetness;
	float auroraWindStrength;
	float auroraWindDirection;
	int auroraCloudParallax;
	float auroraVegetationWind;
	int auroraWeatherTransitions;
	float auroraSkyCloudAmount;
	float auroraRain;
	float auroraSnow;
	int auroraWorldDetailPass;
	int auroraUnderwaterSilhouettes;
	float auroraDetailDistance;
	vec2 auroraWeatherWorldOffset;

    float colorBlindnessIntensity;
    float gammaCorrection;
    float saturation;
	float contrast;
    int colorFilterPrevious;
    int colorFilter;
    float colorFilterFade;

    ivec2 sceneResolution;
    ivec2 tiledLightingResolution;

    vec3 ambientColor;
    float ambientStrength;
    vec3 lightColor;
    float lightStrength;
    vec3 underglowColor;
    float underglowStrength;

    int useFog;
    float fogDepth;
    vec3 fogColor;
    float groundFogStart;
    float groundFogEnd;
    float groundFogOpacity;

    vec3 waterColorLight;
    vec3 waterColorMid;
    vec3 waterColorDark;

    bool underwaterEnvironment;
    bool underwaterCaustics;
    vec3 underwaterCausticsColor;
    float underwaterCausticsStrength;

    vec3 lightDir;

    int pointLightsCount;

    vec3 cameraPos;
    mat4 viewMatrix;
    mat4 projectionMatrix;
    mat4 invProjectionMatrix;
    mat4 lightProjectionMatrix;

    float lightningBrightness;
    float elapsedTime;
};
