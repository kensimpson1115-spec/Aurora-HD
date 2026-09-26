package rs117.hd.aurora.environment;

import java.util.Locale;

/**
 * Conservative material-name classifier used before enabling Aurora vertex wind.
 * It intentionally recognizes only strongly vegetation-specific names so buildings,
 * fences and props cannot start swaying from broad heuristics.
 */
public final class AuroraVegetationClassifier {
    public enum Kind { NONE, GRASS, LEAF, BRANCH }

    private AuroraVegetationClassifier() {}

    public static Kind classifyMaterial(String materialName) {
        if (materialName == null) return Kind.NONE;
        String n = materialName.toLowerCase(Locale.ROOT);
        if (n.contains("grass_blade") || n.equals("grass_1") || n.equals("grass_2") || n.equals("grass_3"))
            return Kind.GRASS;
        if (n.contains("leaf") || n.contains("leaves") || n.contains("foliage"))
            return Kind.LEAF;
        if (n.contains("branch") || n.contains("twig"))
            return Kind.BRANCH;
        return Kind.NONE;
    }

    public static float windResponse(Kind kind) {
        switch (kind) {
            case GRASS: return 1.00f;
            case LEAF: return 0.72f;
            case BRANCH: return 0.22f;
            default: return 0f;
        }
    }
}
