# Advanced development — 1.6.0

## Rendering contract

The order is global exposure/balance → exposure-dependent film response and push/pull → authored emulsion → stock or advanced halation → stock/adaptive grain → film-strength blend → scanner interpretation → creative finishing/vignette → local development. Preview, reference optimization, single export and batch export all call Engine.develop. Mask overlays use a separate preview image and are never composited into output files.

New Development values default neutral. Missing `development` and `masks` keys decode to defaults, preserving earlier recipes. The legacy halation branch is retained when Edge halation is zero. Neutral scan returns its input directly. Native grain remains the default; new format/channel/tonal controls opt into variations. All settings and mask strokes are part of the recipe, saved recipes and session records.

## Authored models

- Exposure response introduces exposure-dependent saturation, channel gains and highlight shoulder compression; reversal profiles use an earlier shoulder. Push/pull independently changes contrast, toe/shoulder, color and grain without applying an exposure offset.
- Adaptive grain varies texture strength by luminance, with channel variation and 35mm/120/110 scale/amount interpretations. This is a deterministic noise field, not a scanned grain library or a physical emulsion model.
- Advanced halation seeds from thresholded bright transitions, blurs and colors the edge energy, then screens it over the developed film. Threshold, spread, hue and intensity are independent controls. Smooth bright regions do not seed an edge halo. The legacy glow remains available at zero advanced amount.
- Scanner variants are Neutral, Warm minilab, Cool editorial and Soft print. Scanner strength blends the authored interpretation, with independent scan contrast and sharpening. No manufacturer/scanner calibration is implied.
- Local masks support radial/gradient/brush/luminance/hue selection, enable/invert, exposure/warmth/saturation/contrast/softness. Range masks evaluate against the same pre-local image. Spatial coordinates are normalized and top-origin in saved recipes. Brush paint/erase strokes rasterize up to 1024 pixels wide and feather before blending. Up to 16 masks are offered in the interface. Geometry carries across batch images; no subject detection is performed.
- Reference statistics now include weighted shadow/highlight red–green and blue–green relationships. Matching adjusts the existing seven global parameters while preserving development, scanner and local-mask settings.

## Verification

35 automated tests cover the existing rendering/export/batch/recipe behavior and new neutral defaults, exposure response, push/pull, adaptive/channel/format grain, bright-edge halation and its controls, scanner strength and sharpening, every mask type, mask coordinates/inversion/locality, brush erase, mask undo/persistence, full advanced-recipe roundtrip, and JPEG/PNG/TIFF output. Reference matching retains the new settings. Native UI checks used a temporary chart and preserved the user's photograph: development sliders, format choice, scanner choice, radial placement, local exposure, brush paint/erase, finishing placement and hiding overlays.

## Primary API references

The implementation uses Core Image’s documented [gradient generators](https://developer.apple.com/documentation/coreimage/gradient-filters), [edge filter](https://developer.apple.com/documentation/coreimage/ciedges), and [filter catalog/compositing operations](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html). The artistic response parameters are authored for Silverroom, not measured manufacturer data.
