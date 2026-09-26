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
package rs117.hd;

import net.runelite.client.config.Config;
import net.runelite.client.config.ConfigGroup;
import net.runelite.client.config.ConfigItem;
import net.runelite.client.config.ConfigSection;
import net.runelite.client.config.Range;
import net.runelite.client.config.Units;
import rs117.hd.config.AntiAliasingMode;
import rs117.hd.config.AuroraAtmosphereStrength;
import rs117.hd.config.AuroraDayCycleSpeed;
import rs117.hd.config.AuroraGraphicsPreset;
import rs117.hd.config.AuroraFpsLimit;
import rs117.hd.config.AuroraTimeOfDay;
import rs117.hd.config.AuroraWaterPreset;
import rs117.hd.config.AuroraWeatherProfile;
import rs117.hd.config.ColorBlindMode;
import rs117.hd.config.ColorFilter;
import rs117.hd.config.Contrast;
import rs117.hd.config.CpuUsageLimit;
import rs117.hd.config.DefaultBoolean;
import rs117.hd.config.DefaultSkyColor;
import rs117.hd.config.DynamicLights;
import rs117.hd.config.FogDepthMode;
import rs117.hd.config.GroundBlending;
import rs117.hd.config.InfernalCape;
import rs117.hd.config.Saturation;
import rs117.hd.config.SceneScalingMode;
import rs117.hd.config.SeasonalHemisphere;
import rs117.hd.config.SeasonalTheme;
import rs117.hd.config.ShadingMode;
import rs117.hd.config.ShadowFiltering;
import rs117.hd.config.ShadowMode;
import rs117.hd.config.ShadowResolution;
import rs117.hd.config.TextureResolution;
import rs117.hd.config.UIScalingMode;
import rs117.hd.config.VanillaShadowMode;

import static rs117.hd.HdPlugin.MAX_DISTANCE;
import static rs117.hd.HdPlugin.MAX_FOG_DEPTH;
import static rs117.hd.HdPluginConfig.*;
import static rs117.hd.utils.MathUtils.*;

@ConfigGroup(CONFIG_GROUP)
public interface HdPluginConfig extends Config
{
	String CONFIG_GROUP = "aurora-hd";

	/*====== Aurora settings ======*/

	@ConfigSection(
		name = "Graphics",
		description = "Core Aurora renderer quality, shadows, materials and distance",
		position = 0
	)
	String graphicsSettings = "graphicsSettings";

	@ConfigSection(
		name = "Environment",
		description = "Lighting, sky, time of day and dynamic weather",
		position = 1
	)
	String environmentSettings = "environmentSettings";

	@ConfigSection(
		name = "Water",
		description = "Aurora water motion, reflections and subtle underwater detail",
		position = 2
	)
	String waterSettings = "waterSettings";

	@ConfigSection(
		name = "Seasons",
		description = "Automatic or manual seasonal world appearance",
		position = 3
	)
	String seasonsSettings = "seasonsSettings";

	@ConfigSection(
		name = "Display",
		description = "Resolution, scaling, accessibility and final image controls",
		position = 4
	)
	String displaySettings = "displaySettings";

	@ConfigSection(
		name = "Compatibility",
		description = "Optional legacy area appearance choices retained by Aurora",
		position = 5,
		closedByDefault = true
	)
	String compatibilitySettings = "compatibilitySettings";

	@ConfigSection(
		name = "Developer",
		description = "Diagnostics and internal renderer controls",
		position = 6,
		closedByDefault = true
	)
	String developerSettings = "developerSettings";

	// Compatibility aliases keep existing annotation wiring and saved config keys
	// stable while the visible menu is organized into Aurora-owned sections.
	String auroraSettings = graphicsSettings;
	String generalSettings = displaySettings;

	@ConfigItem(keyName = "auroraEnhancements", name = "Enable Aurora enhancements",
		description = "Enable Aurora's integrated terrain, water and color pipeline.",
		position = 0, section = auroraSettings)
	default boolean auroraEnhancements() { return true; }

	String KEY_AURORA_GRAPHICS_PRESET = "auroraGraphicsPreset";
	@ConfigItem(keyName = KEY_AURORA_GRAPHICS_PRESET, name = "Aurora graphics preset",
		description = "Coordinated maximum quality budget for Aurora textures, shadows, lighting, atmosphere, world detail and distance. Existing manual sub-settings may reduce quality, but cannot exceed the selected preset.",
		position = 1, section = auroraSettings)
	default AuroraGraphicsPreset auroraGraphicsPreset() { return AuroraGraphicsPreset.HIGH; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraTerrainDetail", name = "Terrain detail",
		description = "World-space macro variation and fine natural-ground detail.",
		hidden = true,
		position = 1, section = auroraSettings)
	default int auroraTerrainDetail() { return auroraGraphicsPreset().terrainDetail; }

	@ConfigItem(keyName = "auroraWaterPreset", name = "Water preset",
		description = "One coordinated profile for motion, clarity, reflection and shoreline foam.",
		position = 0, section = waterSettings)
	default AuroraWaterPreset auroraWaterPreset() { return auroraGraphicsPreset().waterPreset; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraWaterDynamics", name = "Water strength",
		description = "One overall strength control for the selected Aurora water preset.",
		position = 1, section = waterSettings)
	default int auroraWaterDynamics() { return auroraGraphicsPreset().waterStrength; }

	@ConfigItem(keyName = "auroraUnderwaterSilhouettes", name = "Subtle underwater shadows",
		description = "Rare procedural fish-like shadows beneath clear moving water, strongest in Ocean 3.0. They are intentionally faint and are disabled during storms.",
		position = 2, section = waterSettings)
	default boolean auroraUnderwaterSilhouettes() { return true; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraColorGrade", name = "Aurora color grade",
		description = "Strength of Aurora's modern contrast and natural-color separation.",
		hidden = true,
		position = 4, section = auroraSettings)
	default int auroraColorGrade() { return auroraGraphicsPreset().colorGrade; }

	@ConfigItem(keyName = "auroraAtmosphereStrength", name = "Aurora atmosphere",
		description = "Strength of Aurora aerial perspective.",
		position = 0, section = environmentSettings)
	default AuroraAtmosphereStrength auroraAtmosphereStrength() { return auroraGraphicsPreset().atmosphereStrength; }



	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraHaze", name = "Atmospheric haze",
		description = "Internal Aurora aerial-perspective density.",
		hidden = true,
		position = 6, section = auroraSettings)
	default int auroraHaze() { return 18; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraCloudShadows", name = "Moving cloud shadows",
		description = "Projects broad, soft, wind-driven cloud shadows through directional sunlight.",
		hidden = true,
		position = 7, section = auroraSettings)
	default int auroraCloudShadows() { return auroraGraphicsPreset().cloudShadows; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraDryDust", name = "Dry-terrain dust",
		description = "Internal placeholder until a real dry-weather particle/surface system replaces it.",
		hidden = true,
		position = 8, section = auroraSettings)
	default int auroraDryDust() { return 20; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraMaterialDepth", name = "Terrain material depth",
		description = "Adds stronger material-scale breakup, pores, grain and embedded ground detail.",
		hidden = true,
		position = 9, section = auroraSettings)
	default int auroraMaterialDepth() { return auroraGraphicsPreset().materialDepth; }

	@ConfigItem(keyName = "auroraWeather", name = "Dynamic weather",
		description = "Master automatic weather system: clouds, cloud shadows, water/wind response and precipitation. Turn off to disable automatic weather.",
		position = 1, section = environmentSettings)
	default boolean auroraWeather() { return true; }

	String KEY_AURORA_ENVIRONMENTAL_EFFECTS = "auroraEnvironmentalEffects";
	@ConfigItem(keyName = KEY_AURORA_ENVIRONMENTAL_EFFECTS, name = "Environmental effects",
		description = "Extra weather-linked surface response such as wetness/dryness and material response. Clouds, cloud shadows, wind/water response and precipitation belong to Dynamic weather.",
		position = 2, section = environmentSettings)
	default boolean auroraEnvironmentalEffects() { return true; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraCloudCover", name = "Ground cloud-shadow cover",
		description = "Coverage of Aurora's moving ground-shadow field. This is intentionally independent from visible sky clouds.",
		hidden = true,
		position = 12, section = auroraSettings)
	default int auroraCloudCover() { return 86; }


	@ConfigItem(keyName = "auroraSky", name = "Aurora sky",
		description = "Render Aurora's blue sky, clouds, sun, moon and stars behind the scene.",
		position = 3, section = environmentSettings)
	default boolean auroraSky() { return auroraGraphicsPreset().sky; }

	@ConfigItem(keyName = "auroraTimeOfDay", name = "Time of day",
		description = "Select the fixed celestial time used when the day cycle is off.",
		position = 4, section = environmentSettings)
	default AuroraTimeOfDay auroraTimeOfDay() { return AuroraTimeOfDay.NOON; }

	@ConfigItem(keyName = "auroraDayCycleSpeed", name = "Day-cycle speed",
		description = "Controls automatic celestial progression.",
		position = 5, section = environmentSettings)
	default AuroraDayCycleSpeed auroraDayCycleSpeed() { return AuroraDayCycleSpeed.OFF; }





	@ConfigItem(keyName = "auroraCelestialDebug", name = "Celestial debug",
		description = "Internal celestial-path diagnostic.",
		hidden = true,
		position = 0, section = developerSettings)
	default boolean auroraCelestialDebug() { return false; }

	@ConfigItem(keyName = "auroraLodDebug", name = "LOD debug",
		description = "Developer view: tints the live scene path so material/render coverage can be verified quickly.",
		hidden = true,
		position = 1, section = developerSettings)
	default boolean auroraLodDebug() { return false; }

	@ConfigItem(keyName = "auroraLocalLights", name = "Aurora local lights",
		description = "Strengthens animated fire/torch flicker at night while retaining the proven 117 light transport infrastructure.",
		hidden = true,
		position = 21, section = auroraSettings)
	default boolean auroraLocalLights() { return true; }


	@ConfigItem(keyName = "auroraCelestialLighting", name = "Celestial lighting",
		description = "Lets Aurora's celestial clock drive physical day/night illumination independently of whether the moon and stars are drawn.",
		hidden = true,
		position = 22, section = auroraSettings)
	default boolean auroraCelestialLighting() { return true; }

	@ConfigItem(keyName = "auroraRenderMoon", name = "Render moon",
		description = "Draw Aurora's moon. Celestial lighting can remain enabled when this is disabled.",
		hidden = true,
		position = 23, section = auroraSettings)
	default boolean auroraRenderMoon() { return true; }

	@ConfigItem(keyName = "auroraRenderStars", name = "Render stars",
		description = "Draw Aurora's celestial-sphere star field.",
		hidden = true,
		position = 24, section = auroraSettings)
	default boolean auroraRenderStars() { return true; }

	@ConfigItem(keyName = "auroraMaterialResponse", name = "Aurora material response",
		description = "Experimental physical-response pass for terrain/material classes while retaining 117 texture and material plumbing.",
		hidden = true,
		position = 25, section = auroraSettings)
	default boolean auroraMaterialResponse() { return auroraGraphicsPreset().materialResponse; }

	@ConfigItem(keyName = "auroraCloudLightCoupling", name = "Cloud-light coupling",
		description = "Lets Aurora cloud cover reduce direct sunlight while retaining ambient skylight.",
		hidden = true,
		position = 26, section = auroraSettings)
	default boolean auroraCloudLightCoupling() { return auroraGraphicsPreset().cloudLightCoupling; }

	@ConfigItem(keyName = "auroraVisibleClouds", name = "Visible 3D-style clouds",
		description = "Renders Aurora's layered depth-lit cloud field in the sky instead of relying only on ground cloud shadows.",
		hidden = true,
		position = 27, section = auroraSettings)
	default boolean auroraVisibleClouds() { return auroraGraphicsPreset().visibleClouds; }

	@Range(min = 0, max = 100)
	@ConfigItem(keyName = "auroraCloudDepth", name = "Cloud depth",
		description = "Internal cloud-body depth locked to the proven shallow value.",
		hidden = true,
		position = 28, section = auroraSettings)
	default int auroraCloudDepth() { return 15; }

	@Range(min = 0, max = 100)
	@ConfigItem(keyName = "auroraWetness", name = "Surface wetness (experimental)",
		description = "Weather/material groundwork: darkens terrain and strengthens wet specular response. Automatic rain accumulation comes in the weather-state pass.",
		hidden = true,
		position = 29, section = auroraSettings)
	default int auroraWetness() { return 0; }

	@Range(min = 0, max = 100)
	@ConfigItem(keyName = "auroraWindStrength", name = "World wind strength",
		description = "Shared wind input for Aurora clouds, ocean surface and future vegetation/weather motion.",
		hidden = true,
		position = 30, section = auroraSettings)
	default int auroraWindStrength() { return auroraGraphicsPreset().vegetationWind; }

	@Range(min = 0, max = 360)
	@ConfigItem(keyName = "auroraWindDirection", name = "World wind direction",
		description = "Shared Aurora wind direction in degrees.",
		hidden = true,
		position = 31, section = auroraSettings)
	default int auroraWindDirection() { return 35; }

	@ConfigItem(keyName = "auroraCloudParallax", name = "Dynamic cloud parallax",
		description = "Adds altitude-layer parallax so Aurora clouds occupy a moving sky volume rather than reading like a painted backdrop.",
		hidden = true,
		position = 32, section = auroraSettings)
	default boolean auroraCloudParallax() { return true; }

	@Range(min = 0, max = 100)
	@ConfigItem(keyName = "auroraVegetationWind", name = "Vegetation wind",
		description = "Internal until vegetation geometry classification is safe.",
		hidden = true,
		position = 33, section = auroraSettings)
	default int auroraVegetationWind() { return auroraGraphicsPreset().vegetationWind; }

	@ConfigItem(keyName = "auroraWeatherTransitions", name = "Weather transitions",
		description = "Enables shared environmental transition groundwork for cloud, wind, wetness and ocean response.",
		hidden = true,
		position = 34, section = auroraSettings)
	default boolean auroraWeatherTransitions() { return true; }

	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	@ConfigItem(keyName = "auroraSkyCloudAmount", name = "Visible sky clouds",
		description = "Independent amount of visible Aurora clouds. Ground cloud-shadow coverage remains controlled separately.",
		hidden = true,
		position = 35, section = auroraSettings)
	default int auroraSkyCloudAmount() { return 62; }









	@ConfigItem(keyName = "auroraWeatherProfile", name = "Weather override",
		description = "Automatic follows Dynamic weather. Any named profile overrides the automatic state even while Dynamic weather is enabled.",
		position = 6, section = environmentSettings)
	default AuroraWeatherProfile auroraWeatherProfile() { return AuroraWeatherProfile.MANUAL; }

	@Range(
		max = MAX_DISTANCE
	)
	@Units(" tiles")
	@ConfigItem(
		keyName = "drawDistance",
		name = "Aurora extended view distance",
		description =
			"Aurora render distance in either direction from the camera, up to the renderer scene limit of 184 tiles.<br>" +
			"Depending on where the scene is centered, you might only see 16 tiles in one direction, unless you extend map loading.",
		position = 18,
		hidden = true,
		section = auroraSettings
	)
	default int drawDistance() {
		return auroraGraphicsPreset().drawDistance;
	}

	@Range(
		min = 25,
		max = MAX_DISTANCE
	)
	@Units(" tiles")
	@ConfigItem(
		keyName = "detailDistance",
		name = "Detail distance",
		description =
			"The number of tiles to draw animated models in either direction from the camera, up to a maximum of 184.<br>" +
			"Reducing this can help with performance, particularly in crowded sailing areas.",
		position = 19,
		hidden = true,
		section = auroraSettings
	)
	default int detailDrawDistance() {
		return auroraGraphicsPreset().detailDistance;
	}

	String KEY_EXPANDED_MAP_LOADING_CHUNKS = "expandedMapLoadingChunks";
	@Range(
		max = 5
	)
	@Units(" chunks")
	@ConfigItem(
		keyName = KEY_EXPANDED_MAP_LOADING_CHUNKS,
		name = "Live map loading",
		description =
			"True RuneLite scene expansion. The client extended scene is 184x184 tiles, so five 8-tile chunks is the safe live maximum.<br>" +
			"Aurora horizon target can extend beyond this with cached lower-detail terrain instead of enlarging the live scene.",
		position = 20,
		hidden = true,
		section = auroraSettings
	)
	default int expandedMapLoadingChunks() {
		return auroraGraphicsPreset().expandedMapLoadingChunks;
	}

	String KEY_HIDE_UNRELATED_AREAS = "hideUnrelatedAreas";
	@ConfigItem(
		keyName = KEY_HIDE_UNRELATED_AREAS,
		name = "Hide unrelated areas",
		description = "Hide unrelated areas which you shouldn't see from your current position.",
		position = 21,
		section = auroraSettings
	)
	default boolean hideUnrelatedAreas() {
		return true;
	}

	String KEY_ANTI_ALIASING_MODE = "antiAliasingMode";
	@ConfigItem(
		keyName = KEY_ANTI_ALIASING_MODE,
		name = "Anti-aliasing",
		description = "Aurora presets currently keep MSAA disabled to preserve performance and predictable scaling.",
		hidden = true,
		position = 74,
		section = auroraSettings
	)
	default AntiAliasingMode antiAliasingMode()
	{
		return AntiAliasingMode.DISABLED;
	}

	String KEY_SCENE_RESOLUTION_SCALE = "sceneResolutionScale";
	@ConfigItem(
		keyName = KEY_SCENE_RESOLUTION_SCALE,
		name = "Game resolution",
		description =
			"Render the game at a different resolution and stretch it to fit the screen.<br>" +
			"Reducing this can improve performance, particularly on very high resolution displays.",
		position = 0,
		section = displaySettings
	)
	@Units(Units.PERCENT)
	@Range(min = 1, max = 200)
	default int sceneResolutionScale() {
		return 100;
	}

	@ConfigItem(
		keyName = "sceneScalingMode",
		name = "Game scaling mode",
		description = "The sampling function to use when upscaling the above reduced game resolution.",
		position = 1,
		section = displaySettings
	)
	default SceneScalingMode sceneScalingMode()
	{
		return SceneScalingMode.LINEAR;
	}

	String KEY_UI_SCALING_MODE = "uiScalingMode";
	@ConfigItem(
		keyName = KEY_UI_SCALING_MODE,
		name = "UI scaling mode",
		description =
			"The sampling function to use when the Stretched Mode plugin is enabled.<br>" +
			"Affects how the UI looks with non-integer scaling.",
		position = 2,
		section = displaySettings
	)
	default UIScalingMode uiScalingMode() {
		return UIScalingMode.HYBRID;
	}

	String KEY_ANISOTROPIC_FILTERING_LEVEL = "anisotropicFilteringLevel";
	@Range(
		min = 0,
		max = 16
	)
	@Units("x")
	@ConfigItem(
		keyName = KEY_ANISOTROPIC_FILTERING_LEVEL,
		name = "Anisotropic filtering",
		description =
			"Configures whether mipmapping and anisotropic filtering should be used.<br>" +
			"At zero, mipmapping is disabled and textures look the most pixelated.<br>" +
			"At 1 through 16, mipmapping is enabled, and textures look more blurry and smoothed out.<br>" +
			"The higher you go beyond 1, the less blurry textures will look, up to a certain extent.",
		position = 77,
		hidden = true,
		section = auroraSettings
	)
	default int anisotropicFilteringLevel()
	{
		return auroraGraphicsPreset().anisotropicFilteringLevel;
	}

	String KEY_AURORA_FPS_LIMIT = "auroraFpsLimit";
	@ConfigItem(
		keyName = KEY_AURORA_FPS_LIMIT,
		name = "FPS limit",
		description = "Aurora unlocks RuneLite's normal ~50 FPS renderer cap. Choose an optional cap, or leave it uncapped.",
		position = 3,
		section = displaySettings
	)
	default AuroraFpsLimit auroraFpsLimit()
	{
		return AuroraFpsLimit.UNCAPPED;
	}

	String KEY_AURORA_FPS_OVERLAY = "auroraFpsOverlay";
	@ConfigItem(
		keyName = KEY_AURORA_FPS_OVERLAY,
		name = "FPS overlay",
		description = "Show a compact live FPS counter near the minimap.",
		position = 4,
		section = displaySettings
	)
	default boolean auroraFpsOverlay()
	{
		return true;
	}

	String KEY_COLOR_BLINDNESS = "colorBlindMode";
	@ConfigItem(
		keyName = KEY_COLOR_BLINDNESS,
		name = "Color blindness",
		description = "Adjust colors to make them more distinguishable for people with a certain type of color blindness.",
		position = 13,
		section = generalSettings
	)
	default ColorBlindMode colorBlindness()
	{
		return ColorBlindMode.NONE;
	}

	@ConfigItem(
		keyName = "colorBlindnessIntensity",
		name = "Blindness intensity",
		description = "Specifies how intense the color blindness adjustment should be.",
		position = 14,
		section = generalSettings
	)
	@Units(Units.PERCENT)
	@Range(max = 100)
	default int colorBlindnessIntensity()
	{
		return 100;
	}

	@ConfigItem(
		keyName = "flashingEffects",
		name = "Flashing effects",
		description = "Whether to show rapid flashing effects, such as lightning, in certain areas.",
		position = 15,
		section = generalSettings
	)
	default boolean flashingEffects()
	{
		return false;
	}

	@ConfigItem(
		keyName = "fSaturation",
		name = "Saturation",
		description = "Controls the saturation of the final rendered image.<br>" +
			"Intended to be kept between 0% and 120%.",
		position = 16,
		section = generalSettings
	)
	@Units(Units.PERCENT)
	@Range(min = -500, max = 500)
	default int saturation()
	{
		return round(oldSaturationDropdown().getAmount() * 100);
	}
	@ConfigItem(keyName = "saturation", hidden = true, name = "", description = "")
	default Saturation oldSaturationDropdown()
	{
		return Saturation.DEFAULT;
	}

	@ConfigItem(
		keyName = "fContrast",
		name = "Contrast",
		description = "Controls the contrast of the final rendered image.<br>" +
			"Intended to be kept between 90% and 110%.",
		position = 17,
		section = generalSettings
	)
	@Units(Units.PERCENT)
	@Range(min = -500, max = 500)
	default int contrast()
	{
		return round(oldContrastDropdown().getAmount() * 100);
	}
	@ConfigItem(keyName = "contrast", hidden = true, name = "", description = "")
	default Contrast oldContrastDropdown()
	{
		return Contrast.DEFAULT;
	}

	String KEY_BRIGHTNESS = "screenBrightness";
	@Range(
		min = 25,
		max = 400
	)
	@Units(Units.PERCENT)
	@ConfigItem(
		keyName = KEY_BRIGHTNESS,
		name = "Brightness",
		description =
			"Controls the brightness of the game, excluding UI.<br>" +
			"Adjust until the circle on the left is barely visible.",
		position = 18,
		section = generalSettings
	)
	default int brightness() {
		return 100;
	}

	String KEY_SHADOW_MODE = "shadowMode";
	@ConfigItem(
		keyName = KEY_SHADOW_MODE,
		name = "Aurora shadows",
		description =
			"Render fully dynamic shadows.<br>" +
			"'Off' completely disables shadows.<br>" +
			"'Fast' enables fast shadows without any texture detail.<br>" +
			"'Detailed' enables shadows with support for texture detail.",
		position = 45,
		section = auroraSettings
	)
	default ShadowMode shadowMode() {
		return auroraGraphicsPreset().shadowMode;
	}

	String KEY_SHADOW_RESOLUTION = "shadowResolution";
	@ConfigItem(
		keyName = KEY_SHADOW_RESOLUTION,
		name = "Shadow quality",
		description =
			"The resolution of the shadow map.<br>" +
			"Higher resolutions result in higher quality shadows, at the cost of higher GPU usage.",
		position = 46,
		section = auroraSettings
	)
	default ShadowResolution shadowResolution() {
		return auroraGraphicsPreset().shadowResolution;
	}

	String KEY_SHADOW_FILTERING = "shadowFiltering";
	@ConfigItem(
		keyName = KEY_SHADOW_FILTERING,
		name = "Shadow filtering",
		description =
			"Filtering technique used when smoothing the edges of shadows.<br>" +
			"'Smooth' smooths the shadow pixels evenly (PCF 3x3).<br>" +
			"'Dithered' smooths out pixelation using dithering.<br>" +
			"'Pixelated' retains slightly pixelated shadow edges.",
		hidden = true,
		position = 50,
		section = auroraSettings
	)
	default ShadowFiltering shadowFiltering() {
		return ShadowFiltering.SMOOTH;
	}

	String KEY_SHADOW_TRANSPARENCY = "enableShadowTransparency";
	@ConfigItem(
		keyName = KEY_SHADOW_TRANSPARENCY,
		name = "Shadow transparency",
		description = "Enable partial support for taking model transparency into account.",
		hidden = true,
		position = 51,
		section = auroraSettings
	)
	default boolean shadowTransparency() {
		return true;
	}

	String KEY_ROOF_SHADOWS = "experimentalRoofShadows";
	@ConfigItem(
		keyName = KEY_ROOF_SHADOWS,
		name = "Roof shadows",
		description = "Always cast shadows from roofs, even when they are hidden.",
		hidden = true,
		position = 52,
		section = auroraSettings
	)
	default boolean roofShadows() {
		return false;
	}

	String KEY_EXPAND_SHADOW_DRAW = "expandShadowDraw";
	@ConfigItem(
		keyName = KEY_EXPAND_SHADOW_DRAW,
		name = "Expand shadow draw",
		description =
			"Reduces shadows popping in and out at the edge of the screen by rendering<br>" +
			"shadows for a larger portion of the scene, at the cost of higher GPU usage.",
		hidden = true,
		position = 53,
		section = auroraSettings
	)
	default boolean expandShadowDraw() {
		return false;
	}

	String KEY_DYNAMIC_LIGHTS = "dynamicLights";
	@ConfigItem(
		keyName = KEY_DYNAMIC_LIGHTS,
		name = "Aurora dynamic lights",
		description =
			"The maximum number of dynamic lights visible at once.<br>" +
			"Reducing this may improve performance.",
		position = 44,
		section = auroraSettings
	)
	default DynamicLights dynamicLights() {
		return auroraGraphicsPreset().dynamicLights;
	}

	String KEY_TILED_LIGHTING = "tiledLighting";
	@ConfigItem(
		keyName = KEY_TILED_LIGHTING,
		name = "Tiled lighting",
		description = "Allows rendering <b>a lot</b> more lights simultaneously.",
		hidden = true,
		section = auroraSettings,
		position = 54
	)
	default boolean tiledLighting() {
		return auroraGraphicsPreset().dynamicLights != DynamicLights.NONE;
	}
	@ConfigItem(keyName = KEY_TILED_LIGHTING, hidden = true, name = "", description = "")
	void tiledLighting(boolean enabled);

	String KEY_PROJECTILE_LIGHTS = "projectileLights";
	@ConfigItem(
		keyName = KEY_PROJECTILE_LIGHTS,
		name = "Projectile lights",
		description = "Adds dynamic lights to some projectiles.",
		hidden = true,
		position = 55,
		section = auroraSettings
	)
	default boolean projectileLights() {
		return true;
	}

	String KEY_NPC_LIGHTS = "npcLights";
	@ConfigItem(
		keyName = KEY_NPC_LIGHTS,
		name = "NPC lights",
		description = "Adds dynamic lights to some NPCs.",
		hidden = true,
		position = 56,
		section = auroraSettings
	)
	default boolean npcLights() {
		return true;
	}

	String KEY_ATMOSPHERIC_LIGHTING = "environmentalLighting";
	@ConfigItem(
		keyName = KEY_ATMOSPHERIC_LIGHTING,
		name = "Atmospheric lighting",
		description = "Change environmental lighting based on the current area.",
		hidden = true,
		position = 57,
		section = auroraSettings
	)
	default boolean atmosphericLighting() {
		return true;
	}

	String KEY_VANILLA_SHADOW_MODE = "vanillaShadowMode";
	@ConfigItem(
		keyName = KEY_VANILLA_SHADOW_MODE,
		name = "Vanilla shadows",
		description =
			"Choose whether shadows built into models by Jagex should be hidden. This does not affect clickboxes.<br>" +
			"'Show in PvM' will retain shadows for falling crystals during the Olm fight and other useful cases.<br>" +
			"'Prefer in PvM' will do the above and also disable dynamic shadows in such cases.",
		position = 2,
		section = compatibilitySettings
	)
	default VanillaShadowMode vanillaShadowMode() {
		return VanillaShadowMode.SHOW_IN_PVM;
	}

	String KEY_NORMAL_MAPPING = "normalMapping";
	@ConfigItem(
		keyName = KEY_NORMAL_MAPPING,
		name = "Normal mapping",
		description = "Affects how light interacts with certain materials. Barely impacts performance.",
		hidden = true,
		position = 48,
		section = auroraSettings
	)
	default boolean normalMapping() {
		return auroraGraphicsPreset().normalMapping;
	}

	String KEY_PARALLAX_OCCLUSION_MAPPING = "parallaxOcclusionMappingToggle";
	@ConfigItem(
		keyName = KEY_PARALLAX_OCCLUSION_MAPPING,
		name = "Parallax occlusion mapping",
		description = "Adds more depth to some materials, at the cost of higher GPU usage.",
		hidden = true,
		position = 49,
		section = auroraSettings
	)
	default boolean parallaxOcclusionMapping() {
		return auroraGraphicsPreset().parallaxOcclusionMapping;
	}

	String KEY_SEASONAL_THEME = "seasonalTheme";
	@ConfigItem(
		keyName = KEY_SEASONAL_THEME,
		name = "Seasonal theme",
		description = "Festive themes for Gielinor.",
		position = 0,
		section = seasonsSettings
	)
	default SeasonalTheme seasonalTheme() {
		return SeasonalTheme.AUTOMATIC;
	}

	String KEY_SEASONAL_HEMISPHERE = "seasonalHemisphere";
	@ConfigItem(
		keyName = KEY_SEASONAL_HEMISPHERE,
		name = "Seasonal hemisphere",
		description = "Determines which hemisphere the 'Automatic' Seasonal Theme should consider.",
		hidden = true,
		position = 60,
		section = auroraSettings
	)
	default SeasonalHemisphere seasonalHemisphere() {
		return SeasonalHemisphere.NORTHERN;
	}


	@ConfigItem(
		keyName = "fogDepthMode",
		name = "Fog depth mode",
		description =
			"Determines how the fog amount is controlled.<br>" +
			"'Dynamic' changes fog depth based on the area, while<br>" +
			"'Static' respects the manually defined fog depth.",
		hidden = true,
		position = 61,
		section = auroraSettings
	)
	default FogDepthMode fogDepthMode()
	{
		return FogDepthMode.DYNAMIC;
	}

	@Range(
		max = MAX_FOG_DEPTH
	)
	@Units(" tiles")
	@ConfigItem(
		keyName = "fogDepth",
		name = "Static fog depth",
		description =
			"Specify how far from the edge fog should reach.<br>" +
			"This applies only when 'Fog Depth Mode' is set to 'Static'.",
		hidden = true,
		position = 62,
		section = auroraSettings
	)
	default int fogDepth()
	{
		return 5;
	}

	@ConfigItem(
		keyName = "groundFog",
		name = "Ground fog",
		description = "Enables a height-based fog effect that covers the ground in certain areas.",
		hidden = true,
		position = 63,
		section = auroraSettings
	)
	default boolean groundFog() {
		return true;
	}

	@ConfigItem(
		keyName = "defaultSkyColor",
		name = "Default sky",
		description =
			"Specify a sky color to use when the current area doesn't have a sky color defined.<br>" +
			"This only applies when the default summer seasonal theme is active.<br>" +
			"If set to 'RuneLite Skybox', the sky color from RuneLite's Skybox plugin will be used.<br>" +
			"If set to 'Old School Black', the sky will be black and water will remain blue, but for any<br>" +
			"other option, the water color will be influenced by the sky color.",
		hidden = true,
		position = 64,
		section = auroraSettings
	)
	default DefaultSkyColor defaultSkyColor()
	{
		return DefaultSkyColor.DEFAULT;
	}

	@ConfigItem(
		keyName = "overrideSky",
		name = "Override sky color",
		description = "Forces the default sky color to be used in all environments.",
		hidden = true,
		position = 65,
		section = auroraSettings
	)
	default boolean overrideSky() {
		return false;
	}

	String KEY_MODEL_TEXTURES = "objectTextures";
	@ConfigItem(
		keyName = KEY_MODEL_TEXTURES,
		name = "Model textures",
		description = "Adds new textures to most models. If disabled, the standard game textures will be used instead.",
		position = 38,
		hidden = true,
		section = auroraSettings
	)
	default boolean modelTextures() {
		return auroraGraphicsPreset().modelTextures;
	}

	String KEY_GROUND_TEXTURES = "groundTextures";
	@ConfigItem(
		keyName = KEY_GROUND_TEXTURES,
		name = "Ground textures",
		description = "Adds new textures to most ground tiles.",
		position = 39,
		hidden = true,
		section = auroraSettings
	)
	default boolean groundTextures()
	{
		return auroraGraphicsPreset().groundTextures;
	}

	String KEY_TEXTURE_RESOLUTION = "textureResolution";
	@ConfigItem(
		keyName = KEY_TEXTURE_RESOLUTION,
		name = "Texture resolution",
		description = "Controls the resolution used for all in-game textures.",
		position = 40,
		hidden = true,
		section = auroraSettings
	)
	default TextureResolution textureResolution()
	{
		return auroraGraphicsPreset().textureResolution;
	}

	String KEY_GROUND_BLENDING = "groundBlendingv2";
	@ConfigItem(
		keyName = KEY_GROUND_BLENDING,
		name = "Ground blending",
		description =
			"Controls whether ground tiles should blend into each other, or have distinct edges.<br>" +
			"When set to 'Textures only', textures may blend between tiles, but not their colors.",
		position = 41,
		hidden = true,
		section = auroraSettings
	)
	default GroundBlending groundBlending()
	{
		return groundBlendingv1() ? auroraGraphicsPreset().groundBlending : GroundBlending.TEXTURES_ONLY;
	}
	@ConfigItem(keyName = "groundBlending", hidden = true, name = "", description = "")
	default boolean groundBlendingv1() {
		return true;
	}

	@ConfigItem(
		keyName = "underwaterCaustics",
		name = "Underwater caustics",
		description = "Apply underwater lighting effects to imitate sunlight passing through waves on the surface.",
		hidden = true,
		position = 66,
		section = auroraSettings
	)
	default boolean underwaterCaustics()
	{
		return true;
	}

	String KEY_WIND_DISPLACEMENT = "windDisplacement";
	@ConfigItem(
		keyName = KEY_WIND_DISPLACEMENT,
		name = "Wind displacement",
		description = "Controls whether things like grass and leaves should be affected by wind.",
		position = 42,
		hidden = true,
		section = auroraSettings
	)
	default boolean windDisplacement() {
		return auroraGraphicsPreset().windDisplacement;
	}

	String KEY_CHARACTER_DISPLACEMENT = "characterDisplacement";
	@ConfigItem(
		keyName = KEY_CHARACTER_DISPLACEMENT,
		name = "Character displacement",
		description = "Let players & NPCs affect things like grass whilst walking around.",
		hidden = true,
		position = 67,
		section = auroraSettings
	)
	default boolean characterDisplacement() {
		return true;
	}

	String KEY_HIDE_VANILLA_WATER_EFFECTS = "hideVanillaWaterEffects";
	@ConfigItem(
		keyName = KEY_HIDE_VANILLA_WATER_EFFECTS,
		name = "Hide vanilla water ripples",
		description = "Hide vanilla ripples found around objects floating in the water.",
		hidden = true,
		position = 68,
		section = auroraSettings
	)
	default boolean hideVanillaWaterEffects() { return true; }

	String KEY_POH_THEME_ENVIRONMENTS = "pohThemeEnvironments";
	@ConfigItem(
		keyName = KEY_POH_THEME_ENVIRONMENTS,
		name = "Player-owned house themes",
		description = "Change the environmental lighting based on the POH style.",
		hidden = true,
		position = 69,
		section = auroraSettings
	)
	default boolean pohThemeEnvironments() { return true; }

	String KEY_CPU_USAGE_LIMIT = "cpuUsageLimit";
	@ConfigItem(
		keyName = KEY_CPU_USAGE_LIMIT,
		name = "CPU usage",
		description =
			"Specify how much of your processor the plugin should be allowed to use.<br>" +
			"If you play with multiple clients or use other heavy programs on the side,<br>" +
			"reducing this may improve their performance.<br>" +
			"Defaults to Max, allowing the processor to be fully utilized.",
		hidden = true,
		section = generalSettings,
		position = -100
	)
	default CpuUsageLimit cpuUsageLimit() {
		return CpuUsageLimit.MAX;
	}

	String KEY_POWER_SAVING = "powerSaving";
	@ConfigItem(
		keyName = KEY_POWER_SAVING,
		name = "Reduce CPU when unfocused",
		description = "Automatically reduce CPU load when the game has not been in focus for 15 seconds.",
		hidden = true,
		section = generalSettings,
		position = -99
	)
	default boolean powerSaving() {
		return false;
	}

	String KEY_MACOS_INTEL_WORKAROUND = "macosIntelWorkaround";
	@ConfigItem(
		keyName = KEY_MACOS_INTEL_WORKAROUND,
		name = "Fix broken colors on Intel Macs",
		description = "Workaround for visual artifacts found on some Intel GPU drivers on macOS.",
		warning =
			"This setting can cause RuneLite to crash, and it can be difficult to undo.\n" +
			"Only enable it if you are seeing broken colors. Are you sure you want to enable this setting?",
		hidden = true,
		section = generalSettings
	)
	default boolean macosIntelWorkaround()
	{
		return false;
	}

	String KEY_INFERNAL_CAPE = "infernalCape";
	@ConfigItem(
		keyName = KEY_INFERNAL_CAPE,
		name = "Infernal cape",
		description =
			"Replace the infernal cape texture with a more detailed version.<br>" +
			"Note, with Anisotropic Filtering above zero, the cape may look blurry when zoomed out.",
		hidden = true,
		section = auroraSettings
	)
	default InfernalCape infernalCape() {
		return InfernalCape.HD;
	}

	String KEY_VANILLA_COLOR_BANDING = "vanillaColorBanding";
	@ConfigItem(
		keyName = KEY_VANILLA_COLOR_BANDING,
		name = "Vanilla color banding",
		description =
			"Blend between colors similarly to how it works in vanilla, with clearly defined bands of color.<br>" +
			"This isn't really noticeable on textured surfaces, and is intended to be used without ground textures.",
		hidden = true,
		section = auroraSettings
	)
	default boolean vanillaColorBanding() {
		return false;
	}

	String KEY_LOW_MEMORY_MODE = "lowMemoryMode";
	@ConfigItem(
		keyName = KEY_LOW_MEMORY_MODE,
		name = "Low memory mode",
		description = "Turns off features which require extra memory, such as model caching, faster scene loading & extended scene loading.",
		warning =
			"<html>This <b>will not</b> result in better performance. It is recommended only if you are unable to install<br>" +
			"the 64-bit version of RuneLite, or if your computer has a very low amount of memory available.</html>",
		hidden = true,
		section = generalSettings
	)
	default boolean lowMemoryMode() {
		return false;
	}

	String KEY_COLOR_FILTER = "colorFilter";
	@ConfigItem(
		keyName = KEY_COLOR_FILTER,
		name = "Color filter",
		description = "Apply a color filter to the game as a post-processing effect.",
		hidden = true,
		section = generalSettings
	)
	default ColorFilter colorFilter() {
		return ColorFilter.NONE;
	}

	String KEY_REMOVE_VERTEX_SNAPPING = "removeVertexSnapping";
	@ConfigItem(
		keyName = KEY_REMOVE_VERTEX_SNAPPING,
		name = "Remove vertex snapping",
		description =
			"Removes vertex snapping from most animations.<br>" +
			"Most animations are barely affected by this, and it only has an effect if the animation smoothing plugin is turned off.<br>" +
			"To see quite clearly what impact this option has, a good example is the godsword idle animation.",
		hidden = true,
		section = auroraSettings
	)
	default boolean removeVertexSnapping() {
		return true;
	}

	String KEY_FILL_GAPS_IN_TERRAIN = "fillGapsInTerrain";
	@ConfigItem(
		keyName = KEY_FILL_GAPS_IN_TERRAIN,
		name = "Fill gaps in terrain",
		description = "Attempt to patch all holes in the ground, such as around trapdoors and ladders.",
		hidden = true,
		section = auroraSettings
	)
	default boolean fillGapsInTerrain() {
		return true;
	}

	String KEY_FLAT_SHADING = "flatShading";
	@ConfigItem(
		keyName = KEY_FLAT_SHADING,
		name = "Flat shading",
		description = "Gives a more low-poly look to the game.",
		hidden = true,
		section = auroraSettings
	)
	default boolean flatShading() {
		return false;
	}

	String KEY_WINDOWS_HDR_CORRECTION = "windowsHdrCorrection";
	@ConfigItem(
		keyName = KEY_WINDOWS_HDR_CORRECTION,
		name = "Windows HDR correction",
		description =
			"Correctly simulates SDR gamma 2.2 when Windows is in HDR mode. Note, this does not<br>" +
			"enable HDR, it only works around an issue within Windows' HDR implementation.",
		hidden = true,
		section = generalSettings
	)
	default boolean windowsHdrCorrection() {
		return false;
	}

	String KEY_LEGACY_TOB_ENVIRONMENT = "legacyTobEnvironment";
	@ConfigItem(
		keyName = KEY_LEGACY_TOB_ENVIRONMENT,
		name = "Legacy Theatre of Blood",
		description =
			"Previously, Theatre of Blood used to look a whole lot more blue, which<br>" +
			"some people grew really used to. This option brings back that same old look.",
		section = compatibilitySettings,
		position = 0
	)
	default boolean legacyTobEnvironment() {
		return false;
	}

	String KEY_LEGACY_TZHAAR_RESKIN = "tzhaarHD";
	@ConfigItem(
		keyName = KEY_LEGACY_TZHAAR_RESKIN,
		name = "Legacy TzHaar city reskin",
		description = "Recolors the TzHaar city of Mor Ul Rek to give it an appearance similar to that of its 2008 HD variant.",
		section = compatibilitySettings,
		position = 1
	)
	default boolean legacyTzHaarReskin() {
		return false;
	}

	String KEY_FASTER_MODEL_HASHING = "experimentalFasterModelHashing";
	@ConfigItem(
		keyName = KEY_FASTER_MODEL_HASHING,
		name = "Use faster model hashing",
		description = "Should increase performance at the expense of potential graphical issues.",
		hidden = true,
		section = auroraSettings
	)
	default boolean fasterModelHashing() {
		return true;
	}

	String KEY_ZONE_STREAMING = "experimentalZoneStreaming";
	@ConfigItem(
		keyName = KEY_ZONE_STREAMING,
		name = "Zone streaming",
		description =
			"Load zones in parallel in the background, switching to new scenes almost instantly.<br>" +
			"You will see zones appear when they are loaded, instead of having to wait for them all at once.",
		hidden = true,
		section = auroraSettings
	)
	default boolean zoneStreaming() {
		return true;
	}

	String KEY_PRESERVE_VANILLA_NORMALS = "experimentalPreserveVanillaNormals";
	@ConfigItem(
		keyName = KEY_PRESERVE_VANILLA_NORMALS,
		name = "Preserve vanilla normals",
		description = "Preserve the game's original model normals where available. These can be less accurate than Aurora's generated normals.",
		hidden = true,
		section = auroraSettings
	)
	default boolean preserveVanillaNormals() {
		return false;
	}

	String KEY_SHADING_MODE = "experimentalShadingMode";
	@ConfigItem(
		keyName = KEY_SHADING_MODE,
		name = "Shading mode",
		description =
			"If you prefer playing without shadows, maybe you'll prefer vanilla shading or no shading as well.<br>" +
			"Keep in mind, with vanilla shading used alongside shadows, you can end up with double shading.",
		hidden = true,
		section = auroraSettings
	)
	default ShadingMode shadingMode() {
		return ShadingMode.DEFAULT;
	}

	String KEY_DECOUPLE_WATER_FROM_SKY_COLOR = "experimentalDecoupleWaterFromSkyColor";
	@ConfigItem(
		keyName = KEY_DECOUPLE_WATER_FROM_SKY_COLOR,
		name = "Decouple water from sky color",
		description = "Some people prefer the water staying blue even with a different sky color active.",
		hidden = true,
		section = auroraSettings
	)
	default boolean decoupleSkyAndWaterColor() {
		return false;
	}

	String KEY_WIREFRAME = "wireframe";
	@ConfigItem(
		keyName = KEY_WIREFRAME,
		name = "Wireframe",
		description = "Show the edges of individual triangles in the scene.",
		hidden = true,
		section = auroraSettings
	)
	default boolean wireframe() {
		return false;
	}

	String KEY_TILED_LIGHTING_IMAGE_STORE = "experimentalTiledLightingImageStore";
	@ConfigItem(
		keyName = KEY_TILED_LIGHTING_IMAGE_STORE,
		name = "Use tiled lighting image store",
		description = "If you experience any issues with tiled lighting, disabling this <i>might</i> help.",
		hidden = true,
		section = auroraSettings
	)
	default boolean tiledLightingImageLoadStore() {
		return true;
	}

	String KEY_INDIRECT_DRAW = "experimentalIndirectDraw";
	@ConfigItem(
		keyName = KEY_INDIRECT_DRAW,
		name = "Indirect draw",
		description =
			"Indirect draw is currently only enabled automatically for Nvidia GPUs.<br>" +
			"Enabling this <i>might</i> improve performance, if it is supported by your system.",
		hidden = true,
		section = auroraSettings
	)
	default DefaultBoolean indirectDraw() {
		return DefaultBoolean.DEFAULT;
	}

	String KEY_STORAGE_BUFFERS = "experimentalStorageBuffers";
	@ConfigItem(
		keyName = KEY_STORAGE_BUFFERS,
		name = "Storage buffers",
		description =
			"Storage buffers may improve performance, but may also cause graphical artifacts on some hardware.<br>" +
			"By default, we disable this automatically for Intel GPUs, since older ones can be problematic.",
		hidden = true,
		section = auroraSettings
	)
	default DefaultBoolean storageBuffers() {
		return DefaultBoolean.DEFAULT;
	}

	String KEY_ASYNC_MODEL_PROCESSING = "asyncModelProcessing";
	@ConfigItem(
		keyName = KEY_ASYNC_MODEL_PROCESSING,
		name = "Multithreaded model processing",
		description = "Process multiple models in parallel to improve performance for animated models.",
		hidden = true,
		section = auroraSettings
	)
	default boolean multithreadedModelProcessing() {
		return true;
	}

}
