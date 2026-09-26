package rs117.hd.config;

import lombok.AllArgsConstructor;

@AllArgsConstructor
public enum InfernalCape {
	HD("Enhanced"),
	LEGACY("Legacy"),
	VANILLA("Vanilla");

	private final String name;

	@Override
	public String toString() {
		return name;
	}
}
