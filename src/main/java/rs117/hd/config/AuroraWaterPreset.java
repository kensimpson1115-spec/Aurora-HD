package rs117.hd.config;

public enum AuroraWaterPreset
{
	CALM_CLEAR("Calm & clear", 0.72f, 1.24f, 0.84f, 0.56f),
	NATURAL("Natural", 1.00f, 0.82f, 0.88f, 0.90f),
	COASTAL("Active coast", 1.25f, 0.72f, 0.94f, 1.18f),
	OCEAN_3("Ocean 3.0", 1.00f, 0.68f, 1.00f, 1.00f),
	STORMY("Stormy", 1.62f, 0.38f, 0.76f, 1.26f);

	private final String name;
	public final float motion;
	public final float clarity;
	public final float reflection;
	public final float foam;

	AuroraWaterPreset(String name, float motion, float clarity, float reflection, float foam)
	{
		this.name = name;
		this.motion = motion;
		this.clarity = clarity;
		this.reflection = reflection;
		this.foam = foam;
	}

	@Override
	public String toString()
	{
		return name;
	}
}
