package rs117.hd.config;

public enum AuroraTimeOfDay
{
	MORNING("Morning", 0.30f),
	NOON("Noon", 0.50f),
	DUSK("Dusk", 0.74f),
	NIGHT("Night", 0.00f);

	public final String label;
	public final float time;

	AuroraTimeOfDay(String label, float time)
	{
		this.label = label;
		this.time = time;
	}

	@Override
	public String toString()
	{
		return label;
	}
}
