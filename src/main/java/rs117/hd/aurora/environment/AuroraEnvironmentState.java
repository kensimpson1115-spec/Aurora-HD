package rs117.hd.aurora.environment;

import javax.inject.Singleton;

/**
 * Shared Living World transition state. Ground-shadow cover and visible sky-cloud
 * amount are deliberately separate because Aurora's best ground shadows need not
 * spatially or numerically match the visible cloud layer.
 */
@Singleton
public final class AuroraEnvironmentState {
    private float shadowCover, skyClouds, wetness, wind, rain, snow;
    private float targetShadowCover, targetSkyClouds, targetWetness, targetWind, targetRain, targetSnow;
    private boolean initialized;

    public void setTargets(float shadowCover, float skyClouds, float wetness, float wind, float rain, float snow) {
        targetShadowCover = saturate(shadowCover);
        targetSkyClouds = saturate(skyClouds);
        targetWetness = saturate(wetness);
        targetWind = saturate(wind);
        targetRain = saturate(rain);
        targetSnow = saturate(snow);
        if (!initialized) {
            this.shadowCover = targetShadowCover;
            this.skyClouds = targetSkyClouds;
            this.wetness = targetWetness;
            this.wind = targetWind;
            this.rain = targetRain;
            this.snow = targetSnow;
            initialized = true;
        }
    }

    public void update(float deltaSeconds) {
        if (!initialized) return;
        float dt = Math.max(0f, Math.min(deltaSeconds, 0.25f));
        shadowCover = approach(shadowCover, targetShadowCover, dt * 0.095f);
        skyClouds = approach(skyClouds, targetSkyClouds, dt * 0.075f);
        wetness = approach(wetness, targetWetness,
            dt * (targetWetness > wetness ? 0.040f : 0.008f));
        wind = approach(wind, targetWind, dt * 0.12f);
        rain = approach(rain, targetRain, dt * 0.18f);
        snow = approach(snow, targetSnow, dt * 0.12f);
    }

    public void snap(float shadowCover, float skyClouds, float wetness, float wind, float rain, float snow) {
        initialized = true;
        this.shadowCover = targetShadowCover = saturate(shadowCover);
        this.skyClouds = targetSkyClouds = saturate(skyClouds);
        this.wetness = targetWetness = saturate(wetness);
        this.wind = targetWind = saturate(wind);
        this.rain = targetRain = saturate(rain);
        this.snow = targetSnow = saturate(snow);
    }

    public float getShadowCover() { return shadowCover; }
    public float getSkyClouds() { return skyClouds; }
    public float getWetness() { return wetness; }
    public float getWind() { return wind; }
    public float getRain() { return rain; }
    public float getSnow() { return snow; }

    private static float approach(float value, float target, float step) {
        if (value < target) return Math.min(target, value + step);
        return Math.max(target, value - step);
    }

    private static float saturate(float v) { return Math.max(0f, Math.min(1f, v)); }
}
