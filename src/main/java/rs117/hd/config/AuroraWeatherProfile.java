package rs117.hd.config;

/**
 * Aurora weather sky/lighting profiles. MANUAL is retained as the serialized
 * "automatic/no override" sentinel so existing profiles continue to load.
 */
public enum AuroraWeatherProfile {
    MANUAL("Automatic", -1f, -1f, -1f, -1f, 0f, 0f),
    SUNNY("Sunny", 0.30f, 0.18f, 0.20f, 0.00f, 0f, 0f),
    FAIR("Fair", 0.52f, 0.34f, 0.30f, 0.00f, 0f, 0f),
    SCATTERED("Scattered clouds", 0.72f, 0.52f, 0.40f, 0.00f, 0f, 0f),
    CLOUDY("Cloudy", 0.88f, 0.70f, 0.50f, 0.06f, 0f, 0f),
    OVERCAST("Overcast", 0.98f, 0.86f, 0.58f, 0.22f, 0f, 0f),
    RAIN("Rain", 1.00f, 0.90f, 0.68f, 0.72f, 0.78f, 0f),
    SNOW("Snow", 0.96f, 0.84f, 0.42f, 0.28f, 0f, 0.72f),
    STORM_BUILDUP("Storm", 1.00f, 0.94f, 0.82f, 0.82f, 1.00f, 0f);

    public final String label;
    public final float shadowCover;
    public final float skyCloudAmount;
    public final float windStrength;
    public final float wetness;
    public final float rain;
    public final float snow;

    AuroraWeatherProfile(String label, float shadowCover, float skyCloudAmount, float windStrength,
                         float wetness, float rain, float snow) {
        this.label = label;
        this.shadowCover = shadowCover;
        this.skyCloudAmount = skyCloudAmount;
        this.windStrength = windStrength;
        this.wetness = wetness;
        this.rain = rain;
        this.snow = snow;
    }

    public static AuroraWeatherProfile dynamicTarget(double elapsedTime) {
        AuroraWeatherProfile[] sequence = {
            FAIR, SCATTERED, CLOUDY, RAIN, OVERCAST, SCATTERED, SUNNY,
            CLOUDY, STORM_BUILDUP, RAIN, OVERCAST, SNOW, FAIR
        };
        int phase = Math.floorMod((int) Math.floor(elapsedTime / 150.0), sequence.length);
        return sequence[phase];
    }

    @Override
    public String toString() {
        return label;
    }
}
