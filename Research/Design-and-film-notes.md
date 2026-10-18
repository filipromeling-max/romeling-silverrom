# Silverroom — design and film research

## Product model
A photographer imports photographs, tries film stocks, develops a recipe, compares it with the original, and exports a finished image. Objects: source photograph, film stock, development recipe, rendered photograph. The source is immutable; the recipe belongs to the photograph. All processing is local.

## Three concepts considered
1. **Darkroom workbench (chosen):** one persistent photograph, a short contact strip, and immediately visible film/development controls. Compare original and developed images in the same coordinate space. No navigation layer between choosing a film and developing it. Strong task fit, discoverability, precision, accessibility; medium distinctiveness. Risk: too many controls; addressed with a scrollable inspector and three named sections.
2. **Contact-sheet laboratory:** many rendered film variants simultaneously, click a print to enlarge and refine. Strong comparison and distinctiveness; weaker memory efficiency and fine control. Risk: small images obscure grain and subtle tone.
3. **Recipe timeline:** photographs move through exposure, emulsion, texture and export stages. Strong causal explanation; weaker directness and repeated-use efficiency. Risk: implying a mandatory wizard.

## Interaction and state model
Import via native file panel, drag/drop or Finder Open With. Selecting a stock immediately schedules a preview. Sliders continuously update values with debounced rendering. Original/developed halves align; B toggles comparison. Fit/100% toggles a full-resolution render with scrolling. Cmd-Z reverses an adjustment (slider gestures grouped); Cmd-Shift-Z redoes it. Recipes persist per photograph, and named recipes can be reapplied. Export uses a native save panel; source paths are protected against overwrite.

Empty: explicit import action and supported format guidance. Loading: actual indeterminate progress, no invented percent. Preview rendering: status text. Error: native alert with actionable cause where known; source files retained. Success: export status and Finder selection. Recovery: undo/redo, reset, reimport unavailable files, removal from session without file deletion. Native controls provide keyboard and accessibility semantics. Minimum window dimensions preserve usable image and inspector space.

## Assumption-based journey map (not user research)
Actor: photographer seeking film character in digital photographs. Scenario: develop a small shoot without a cataloging workflow.

| | Import | Explore | Develop | Compare | Export |
|---|---|---|---|---|---|
| Action | Open or drop images | Select an emulsion | Adjust light, color, texture | Inspect split image at fit or 100% | Save full-resolution output |
| Assumed mindset | Will my RAW work? | Which character fits? | Keep the photograph believable | Have I gone too far? | Keep my original safe |
| Assumed emotion | Uncertain → | Curious ↗ | Focused → | Critical ↘ | Confident ↗ |
| Opportunity | Decoder errors and format guidance | Stock descriptions and immediate feedback | Continuous sliders and saved recipes | Aligned before/after and undo | Explicit formats, original protection |

Proposed owner: application developer for all phases. Validate with actual photographers; measure successful import, time to first preferred film, comparison discoverability, and successful export. No user-study results are claimed.

## Hasselblad CSS extraction
Retrieved 2026-10-18 from https://www.hasselblad.com/phocus/phocus-mobile-2/ . Raw response is in `hasselblad.html`; embedded style blocks are in `hasselblad-extracted.css`. The response includes many site-wide rules, so frequency counts are not a claim about a single component's computed style.

Observed recurring declarations: black/white surfaces, zero-radius treatments, 1px/2px tracking, Tw Cen and Outfit font families. Adaptation: charcoal image surround, modest warm-neutral selection, thin separators, tracked section labels, system typography. No Hasselblad identity, images or font files are bundled in the application. CSS informs the design; SwiftUI implements the native UI.

## Film evidence and interpretation
Manufacturer descriptions are qualitative evidence. The numeric parameters in Film.swift are authored approximations, not measured sensitometric curves, spectral responses or licensed film profiles. Film results vary with exposure, chemistry, camera, scanner, paper and light. Grain is procedural luminance noise and halation is a thresholded warm glow, not a physical emulsion simulation. Preview uses reduced resolution; evaluate fine texture at 100%.

- Kodak Portra 160 / 400: portrait-oriented natural color and fine grain. https://www.kodakprofessional.com/sites/default/files/wysiwyg/film/KODAKPROFESSIONAL_Film_Brochure2018.pdf
- Kodak Ektar 100: high saturation and very fine grain. https://www.kodak.com/en/still-film/product/professional/ektar-100-film/
- Fujifilm Velvia / Provia: higher saturation and stronger contrast for Velvia; balanced versatility for Provia. https://asset.fujifilm.com/www/ca/files/2020-03/b8a8dcc2937127db89d62a7b953aa9ea/Profilm_misc.pdf
- CineStill 800T: tungsten-oriented rendering and pronounced halation sensitivity. https://cinestill.film/blogs/news/cinestill-800t-in-your-toolbox
- CineStill 50D: daylight-oriented fine-grain interpretation. https://cinestillfilm.com/blogs/news/13167341-a-dps-point-of-view-cinestill-50d-800t-by-rob-hauer
- Ilford HP5 Plus: ISO 400 monochrome, medium contrast. https://www.ilfordphoto.com/amfile/file/download/file/1903/product/693/

Historical, recognizable film names are used to identify artistic references; no manufacturer endorsement or certification is implied. Numerical color casts and grain amounts are creative decisions; descriptions do not validate exact matches.

## Apple implementation references
- https://developer.apple.com/documentation/coreimage/cirawfilter — Apple RAW decoder, camera/OS dependent support.
- https://developer.apple.com/design/human-interface-guidelines/toolbars — native actions and recognizable toolbar behavior. The app uses native buttons, menus, sliders and file dialogs; touch-target limits were not applied to desktop pointer controls.

## Rams check
Useful / unobtrusive / minimal: strong — the photograph dominates and all controls modify it. Honest: strong — approximation disclosed, no fake progress, originals preserved. Understandable: adequate — clear labels and descriptions; validate with photographers. Thorough: adequate — empty/loading/error/undo/persistence covered, but camera-specific RAW QA remains necessary. Long-lasting: strong — system controls, no external dependencies. Efficiency: adequate — serial background processing and debounced reduced previews; 100%/export intentionally uses full resolution. Keep the persistent image. Highest-leverage edit: keep library organization out of this development workspace.

## 1.1 — Creative workbench / Romeling Silverroom

**Intent verbs:** discover, tint, soften, fade, illuminate, compare, keep. **Objects:** photograph, emulsion, color balance, shadow/highlight colors, light source, texture, saved recipe. The relationship that matters most is immediate cause and effect between a gesture and the photograph.

**Concept 0 rejected:** append twelve film buttons and fifteen sliders to the existing inspector. This would bury both the photograph's character and the essential controls.

Three architectures (scores are design judgment, 1–5, not user-study findings):

| Concept | Task fit | Learnability | Density | Directness | Distinctiveness | Scale | Accessibility |
|---|---:|---:|---:|---:|---:|---:|---:|
| Creative workbench: persistent photograph, two-axis color field, light origin placed on image | 5 | 4 | 4 | 5 | 4 | 4 | 4 |
| Contact-sheet comparison: many rendered stock variations, select a print to develop | 4 | 5 | 3 | 4 | 3 | 3 | 4 |
| Development chain: reorder exposure/emulsion/chemistry/print stages | 3 | 3 | 4 | 3 | 4 | 5 | 3 |

Chosen: the creative workbench. It removes the form step for positioning a light leak and combines two related color dimensions into one continuous action. The photo stays fixed and the remaining controls use progressive disclosure. A searchable stock browser replaces the long permanent stock list. Risk: two-dimensional gestures can obscure precision; native sliders provide equivalent independent adjustments, labels expose both axes, and the light-placement overlay names its action. No essential feature depends exclusively on a gesture.

**States:** idle shows current film/color point; hover provides descriptive help; active dragging changes a debounced preview and groups undo; successful changes autosave; failures retain sources and show the existing alert; Cmd-Z reverses a whole gesture or treatment. Treatment buttons change finishing only and retain exposure/white balance/film. Split-tone hues take effect only with nonzero amounts. Light placement displays a target and instruction, with an explicit Done action. Compare, 100% and switching photos leave placement mode. Keyboard users have stock search, native buttons/menus, disclosure sections, and sliders for every custom gesture dimension.

The new recipe decoder supplies neutral defaults for absent fields. There is no migration that rewrites a user's existing film/exposure choices. Rendering tests cover stock output, active creative parameters, old recipes, treatment isolation, opacity and preview/export consistency. Physical RAW fidelity still requires real camera samples.

### Additional primary film references

- Kodak Gold 200 data sheet: https://www.kodak.com/global/plugins/acrobat/en/consumer/products/techInfo/e7022/E7022.pdf
- Kodak UltraMax 400 data sheet: https://www.kodakprofessional.com/sites/default/files/wysiwyg/KodakUltraMax400TechSheet-1.pdf
- Kodak Ektachrome E100: https://www.kodak.com/en/still-film/product/professional/ektachrome-e100-film/
- Kodak T-Max 100: https://www.kodakprofessional.com/photographers/film/black-white/kodak-professional-t-max-100-film/525
- Kodak professional brochure (Portra 800 and Tri-X reference): https://www.kodakprofessional.com/sites/default/files/wysiwyg/film/KODAKPROFESSIONAL_Film_Brochure2018.pdf
- Ilford film-family guidance (Delta/Pan F): https://www.ilfordphoto.com/choosing-your-first-ilford-film/
- CineStill 400D: https://cinestill.film/products/a-new-color-film-400dynamic
- Lomography's color-shifting film overview: https://www.lomography.com/school/what-are-lomochrome-films-fa-g3ebpber
- LomoChrome Purple guide: https://cdn.downloads.lomography.com/downloads/lomochrome-purple-film-guide.pdf
- LomoChrome Metropolis guide: https://cdn.downloads.lomography.com/downloads/lomochrome-metropolis-film-guide.pdf

The selected qualitative anchors are Gold/UltraMax everyday color, E100 neutral reversal rendering, distinct fine/classic/high-speed monochrome textures, 400D soft daylight color, Purple green-to-violet interpretation, and Metropolis muted high-contrast color. Every numeric parameter and selective hue mapping is authored, not measured. Historical stock names identify the intended reference.
