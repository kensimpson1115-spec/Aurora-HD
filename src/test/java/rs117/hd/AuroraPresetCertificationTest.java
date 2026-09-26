package rs117.hd;

import org.junit.Test;
import rs117.hd.config.AntiAliasingMode;
import rs117.hd.config.AuroraGraphicsPreset;

import static org.junit.Assert.*;

/**
 * Source-level certification for Aurora's performance ladder.
 *
 * This deliberately checks budget invariants rather than hardware FPS. Real FPS,
 * frame-time and VRAM certification still has to be measured in RuneLite on real
 * GPUs, but these assertions prevent lower presets from silently retaining
 * expensive higher-preset settings.
 */
public class AuroraPresetCertificationTest
{
    @Test
    public void presetBudgetsAreMonotonicAndSafe()
    {
        AuroraGraphicsPreset[] p = AuroraGraphicsPreset.values();
        assertEquals(6, p.length);

        int lastDraw = -1;
        int lastDetail = -1;
        int lastChunks = -1;

        for (AuroraGraphicsPreset preset : p)
        {
            assertEquals("MSAA must remain off across Aurora presets", AntiAliasingMode.DISABLED, preset.antiAliasingMode);
            assertTrue("draw distance out of live-scene bounds", preset.drawDistance >= 0 && preset.drawDistance <= HdPlugin.MAX_DISTANCE);
            assertTrue("detail distance must not exceed draw distance", preset.detailDistance <= preset.drawDistance);
            assertTrue("RuneLite extended scene supports at most five extra chunks", preset.expandedMapLoadingChunks >= 0 && preset.expandedMapLoadingChunks <= 5);
            assertTrue("draw distance must be monotonic", preset.drawDistance >= lastDraw);
            assertTrue("detail distance must be monotonic", preset.detailDistance >= lastDetail);
            assertTrue("live chunk count must be monotonic", preset.expandedMapLoadingChunks >= lastChunks);

            lastDraw = preset.drawDistance;
            lastDetail = preset.detailDistance;
            lastChunks = preset.expandedMapLoadingChunks;
        }

        assertEquals(1, AuroraGraphicsPreset.VERY_LOW.expandedMapLoadingChunks);
        assertEquals(5, AuroraGraphicsPreset.ULTRA.expandedMapLoadingChunks);
    }

    @Test
    public void lowEndPresetsDoNotEnableWorldDetailTwo()
    {
        // ZoneRenderer enables World Detail 2.0 at terrain detail >= 48.
        assertTrue(AuroraGraphicsPreset.VERY_LOW.terrainDetail < 48);
        assertTrue(AuroraGraphicsPreset.LOW.terrainDetail < 48);
        assertTrue(AuroraGraphicsPreset.MEDIUM.terrainDetail >= 48);
    }
}
