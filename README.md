# Aurora HD

Aurora HD is a RuneLite GPU-renderer plugin derived from the 117 HD codebase and developed as an Aurora-focused graphics fork. It keeps the proven RuneLite HD foundation while experimenting with Aurora-owned water, sky, material, lighting, environment, world-detail, and renderer cleanup work.

This repository is a development build. Disable RuneLite's GPU plugin and any installed 117 HD plugin before enabling Aurora HD.

## Current Build

Version: `0.63.1`

Current development highlights:

- Removed the abandoned secondary fire/torch shadow experiment introduced after the stable lighting baseline. Normal Aurora/117 fire, torch and emissive point lighting—including the existing flicker behavior—remains intact.
- Preserved the 0.62 world/material QA work: repaired sand wrapping, improved rock/boulder response, forged-metal material tuning, and removal of the unused corrupt hedge texture.
- Preserved the settings consolidation around Graphics / Environment / Water / Seasons / Display / Compatibility / Developer.
- Preserved the Plugin Hub cleanup that removed Java reflection and direct `Desktop` URL browsing.
- Replaced ordinary LWJGL `MemoryUtil`, `MemoryStack`, and `BufferUtils` staging allocations with a small Java-NIO direct-buffer utility.
- Reused command-buffer multi-draw scratch buffers and pooled mapped-buffer fallback staging views to reduce allocation churn.
- Very High keeps the 4K directional-shadow budget; Superb alone retains the 8K map.
- The experimental localized fog-bank system remains removed completely.
- Ocean 3.0 temporal motion, World Detail 2.0, seasonal materials, current cloud-shadow behavior, and the zone-renderer-only architecture remain intact.
- Aurora now enables RuneLite's unlocked-FPS renderer path and offers Uncapped / 60 / 45 / 30 FPS targets under Display.
- `build=standard`, Java 11 targeting, and the no-extra-runtime-dependency layout are retained for Plugin Hub review.
- Remaining review item: inherited OpenGL mapped-buffer calls (`glMapBuffer*`) are still part of the renderer transport layer and should be disclosed to RuneLite reviewers as renderer-specific inherited infrastructure rather than hidden or rewritten into a slower per-frame upload path.

## Features

- Integrated GPU renderer based on the 117 HD rendering pipeline.
- Aurora water presets, current accelerated Ocean 3.0 motion, shoreline foam, reflection tuning, and shallow-water visibility controls.
- Aurora sky, moon, stars, day-cycle controls, and environmental effects.
- Cloud-shadow behavior preserved separately from visible sky-cloud amount.
- World-detail material pass for terrain breakup, dry-terrain warmth, wetness, and wind-linked response.
- Aurora graphics presets and consolidated settings ownership.
- Optional FPS overlay plus an Aurora FPS limit selector: Uncapped, 60 FPS, 45 FPS, or 30 FPS.
- Zone renderer is the sole Aurora rendering path; legacy area reskin toggles remain only for Theatre of Blood and TzHaar City.

## Running From IntelliJ

1. Import this folder as a Gradle project.
2. Build the project.
3. Run `src/test/java/rs117/hd/HdPluginTest.java`.
4. Add `-ea` to VM options.
5. Disable RuneLite GPU and the installed 117 HD plugin.
6. Enable `Aurora HD`.

The Gradle `run` task also launches the development client with assertions enabled.

## Performance Notes

Aurora should avoid new object allocation inside render methods, `onGameTick`, `onClientTick`, model-push/upload loops, and other high-frequency paths. Expensive CPU work should be cached, pooled, precomputed, or moved to the existing job system where it is safe to do so. OpenGL calls and RuneLite client-thread-only operations must remain on the correct thread.

Aurora now uses one ZoneRenderer path. The legacy renderer, abandoned cached-horizon renderer, and obsolete checkpoint gates are removed; World Detail 2.0 remains part of the normal Aurora renderer.

## Licensing And Attribution

Aurora HD is derived from 117 HD and retains the upstream BSD 2-Clause license in `LICENSE`. Existing source-file copyright headers and third-party notices must remain intact.

Some bundled assets and helper files carry separate notices or terms. See:

- `LICENSE`
- `NOTICE`
- `src/main/resources/rs117/hd/scene/textures/000_licenses.txt`
- Individual source-file and shader headers

Gradle wrapper scripts include their own Apache 2.0 notices in their file headers. That does not change the overall project license inherited from 117 HD.

## Modification Notice

Aurora-specific changes include renderer settings cleanup, Aurora graphics presets, environmental effects, water and sky work, world-detail material work, performance cleanup, documentation replacement, and repository identity updates. These modifications should not be attributed to the original 117 HD authors unless a source file explicitly says otherwise.

## AI-Assisted Development Notice

Portions of Aurora-specific code, documentation, and cleanup work were produced with AI assistance under user direction and review. AI-assisted additions are modifications to this fork and do not replace or remove upstream attribution.

## Status

Aurora still intentionally retains proven inherited transport infrastructure where rewriting it would add risk without improving rendering. Visual ownership continues to move toward Aurora while upstream attribution remains intact.
