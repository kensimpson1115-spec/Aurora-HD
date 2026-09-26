/*
 * Aurora HD modification.
 * Derived project licensing and upstream notices are retained in the repository root.
 */
package rs117.hd.config;

public enum AuroraFpsLimit
{
	UNCAPPED("Uncapped", 0),
	FPS_60("60 FPS", 60),
	FPS_45("45 FPS", 45),
	FPS_30("30 FPS", 30);

	private final String label;
	public final int target;

	AuroraFpsLimit(String label, int target)
	{
		this.label = label;
		this.target = target;
	}

	@Override
	public String toString()
	{
		return label;
	}
}
