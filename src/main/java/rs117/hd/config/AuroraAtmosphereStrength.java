package rs117.hd.config;

public enum AuroraAtmosphereStrength
{
	OFF("Off", false, 0.0f),
	LOW("Low", true, 0.11f),
	MEDIUM("Medium", true, 0.18f),
	HIGH("High", true, 0.31f);

	public final String label;
	public final boolean enabled;
	public final float haze;

	AuroraAtmosphereStrength(String label, boolean enabled, float haze)
	{
		this.label = label;
		this.enabled = enabled;
		this.haze = haze;
	}

	@Override
	public String toString()
	{
		return label;
	}
}
