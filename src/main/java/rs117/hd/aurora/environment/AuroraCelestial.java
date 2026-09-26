package rs117.hd.aurora.environment;

import rs117.hd.HdPluginConfig;

public final class AuroraCelestial
{
	private static final float TWO_PI = (float) (Math.PI * 2.0);

	private AuroraCelestial()
	{
	}

	public static float time(HdPluginConfig config, double elapsedTime)
	{
		float t = config.auroraTimeOfDay().time;
		if (config.auroraDayCycleSpeed().enabled)
		{
			t = (float) ((t + elapsedTime *
				(0.00002 + (0.00055 - 0.00002) * config.auroraDayCycleSpeed().speed)) % 1.0);
		}
		return t < 0 ? t + 1f : t;
	}

	public static void sunAngles(float[] out, HdPluginConfig config, double elapsedTime)
	{
		float t = time(config, elapsedTime);
		float solarAngle = (t - 0.25f) * TWO_PI;
		float sunHeight = (float) Math.sin(solarAngle);

		// Aurora Lighting 2.0: use one continuous celestial orbit for the shadow
		// camera. During the day this is the sun; at night the opposite half of the
		// orbit behaves like moonlight. Keeping the azimuth continuous avoids the
		// abrupt shadow-direction jumps that occurred when the light was effectively
		// pinned to a limited daytime arc.
		float celestialHeight = (float) Math.pow(Math.abs(sunHeight), 0.80);
		float altitude = (float) Math.toRadians(7.0 + celestialHeight * 59.0);
		float azimuth = (float) Math.toRadians(55.0 + t * 360.0);
		out[0] = altitude;
		out[1] = azimuth;
	}

	private static float smoothstep(float edge0, float edge1, float x)
	{
		float t = Math.max(0f, Math.min(1f, (x - edge0) / (edge1 - edge0)));
		return t * t * (3f - 2f * t);
	}
}
