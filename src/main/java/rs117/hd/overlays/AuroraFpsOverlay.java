package rs117.hd.overlays;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import java.awt.Dimension;
import java.awt.Graphics2D;
import net.runelite.client.ui.FontManager;
import net.runelite.client.ui.overlay.OverlayLayer;
import net.runelite.client.ui.overlay.OverlayManager;
import net.runelite.client.ui.overlay.OverlayPanel;
import net.runelite.client.ui.overlay.OverlayPosition;
import net.runelite.client.ui.overlay.components.LineComponent;
import rs117.hd.HdPlugin;
import rs117.hd.HdPluginConfig;

@Singleton
public class AuroraFpsOverlay extends OverlayPanel {
	private static final int MAX_CACHED_FPS = 999;

	@Inject
	private OverlayManager overlayManager;

	@Inject
	private HdPluginConfig config;

	private boolean active;
	private long lastRenderNanos;
	private float smoothedFps;
	private final LineComponent pendingFrameComponent;
	private final LineComponent[] fpsComponents = new LineComponent[MAX_CACHED_FPS + 1];

	@Inject
	public AuroraFpsOverlay(HdPlugin plugin) {
		super(plugin);
		setLayer(OverlayLayer.ABOVE_WIDGETS);
		setPosition(OverlayPosition.TOP_RIGHT);
		panelComponent.setPreferredSize(new Dimension(72, 0));

		var smallFont = FontManager.getRunescapeSmallFont();
		pendingFrameComponent = buildLine(smallFont, "--");
		for (int i = 0; i < fpsComponents.length; i++) {
			fpsComponents[i] = buildLine(smallFont, Integer.toString(i));
		}
	}

	public void setActive(boolean activate) {
		if (active == activate)
			return;

		active = activate;
		if (activate) {
			overlayManager.add(this);
		} else {
			overlayManager.remove(this);
			lastRenderNanos = 0;
			smoothedFps = 0;
		}
	}

	@Override
	public Dimension render(Graphics2D graphics) {
		if (!config.auroraFpsOverlay())
			return null;

		long now = System.nanoTime();
		if (lastRenderNanos != 0) {
			long elapsed = Math.max(1L, now - lastRenderNanos);
			float instantFps = 1_000_000_000f / elapsed;
			smoothedFps = smoothedFps == 0 ? instantFps : smoothedFps * 0.88f + instantFps * 0.12f;
		}
		lastRenderNanos = now;

		panelComponent.getChildren().add(componentForFps(smoothedFps));
		return super.render(graphics);
	}

	private LineComponent componentForFps(float fps) {
		if (fps == 0)
			return pendingFrameComponent;

		int rounded = Math.max(0, Math.min(MAX_CACHED_FPS, Math.round(fps)));
		return fpsComponents[rounded];
	}

	private static LineComponent buildLine(java.awt.Font font, String rightText) {
		return LineComponent.builder()
			.leftFont(font)
			.left("FPS")
			.rightFont(font)
			.right(rightText)
			.build();
	}
}
