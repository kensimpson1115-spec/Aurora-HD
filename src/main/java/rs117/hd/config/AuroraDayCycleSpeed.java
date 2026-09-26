package rs117.hd.config;

public enum AuroraDayCycleSpeed
{
	OFF("Off", false, 0.0f),
	SLOW("Slow", true, 0.18f),
	MEDIUM("Medium", true, 0.42f),
	FAST("Fast", true, 0.72f);

	public final String label;
	public final boolean enabled;
	public final float speed;

	AuroraDayCycleSpeed(String label, boolean enabled, float speed)
	{
		this.label = label;
		this.enabled = enabled;
		this.speed = speed;
	}

	@Override
	public String toString()
	{
		return label;
	}
}
