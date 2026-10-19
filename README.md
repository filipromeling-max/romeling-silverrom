# Romeling Silverroom

A native macOS digital darkroom built in SwiftUI, AppKit and Core Image. No web view, account, external service or runtime dependency.

## Download

[Download for Mac](https://filipromeling-max.github.io/romeling-silverrom/) · [Releases and checksums](https://github.com/filipromeling-max/romeling-silverrom/releases)

The DMG contains a universal app for Apple silicon and Intel Macs running macOS 14+. Drag it into Applications. This release is ad-hoc signed, not Apple-notarized. If macOS blocks launch, consult [Apple’s instructions](https://support.apple.com/en-us/102445). Only use Open Anyway if you trust the download.

## Run

Open `dist/Romeling Silverroom.app` after building:

```sh
./scripts/build-app.sh
open "dist/Romeling Silverroom.app"
```

Requires macOS 14 or newer and Xcode command-line tools to build. The build script produces a universal Apple silicon/Intel bundle with an ad-hoc signature. A trusted distribution without Gatekeeper approval requires Developer ID signing and notarization. Open Package.swift in Xcode to develop or debug.

## Workflow

1. Import RAW, JPEG, HEIF, TIFF or PNG with **⌘O**, drag/drop, or Finder Open With.
2. Click **Films** in the live film ribbon to search **20 stocks** by maker/name, or filter Color, Monochrome and Experimental. Kodak: Portra 160/400/800, Gold 200, UltraMax 400, Ektar 100, Ektachrome E100, Tri-X 400, T-Max 100. Fujifilm: Velvia 50, Provia 100F. CineStill: 50D, 400D, 800T. Ilford: HP5 Plus, Delta 100/3200, Pan F Plus. Lomography: LomoChrome Purple, Metropolis.
3. Select **Color**, then drag **Color balance** to change warmth and tint together, or expand Precision controls for individual keyboard-accessible sliders. Develop tone and saturation, add split toning, faded blacks, black depth, or cross-processing. Change grain amount/size, halation, bloom/spread, and vignette.
4. Select **Glow → Light leak**, then click **Place light on image** to drag its origin directly over the image. Hue, spread and precise position remain adjustable in the inspector. Placement switches to the developed image at fit size; Compare or 100% exits placement.
5. Try **Amber & cyan**, **Faded print**, **Nocturne**, or **Sun wash** from **Film & recipes → Creative starting points**. These replace the creative finishing settings while preserving the chosen film, exposure and white balance. **Clean finish** resets that same finishing subset; The Reset menu restores the full default recipe.
6. Use **Compare** for original-only, vertical/horizontal draggable splits, or side-by-side views. **B** toggles original/developed. **⌘0** fits the image, **⌘1** toggles fit/100%, and **⌘− / ⌘=** step zoom from 25% to 400%. Scroll to pan. Double-click the preview in Developed or Original mode to toggle fit/100%.
7. Save a named recipe or export a full-resolution JPEG (95%), PNG (8-bit), or TIFF (16-bit), tagged sRGB. **⇧⌘E** exports JPEG.

**⌘Z / ⇧⌘Z** undo/redo. Develop menu closes an image from the session without deleting the source. The session and recipes automatically save to `~/Library/Application Support/Silverroom/`. Originals are never edited. Referenced files need to remain accessible at their original location. Exports contain rendered pixels and color profiles; source EXIF/IPTC metadata is not copied.

## Honest boundaries

Film profiles are researched creative approximations, not calibrated reproductions. RAW compatibility is provided by Apple's CIRAWFilter and varies by camera and installed macOS. Unsupported RAW files produce an error instead of silently using an embedded JPEG. Preview is downsampled to 1800 pixels; 100% and export render full resolution. Grain is approximate and may look different at fit size. This version supports individual and batch export. It does not include crop, lens profiles, or an archival catalog.

## Validation

```sh
swift test
```

Tests render all twenty films, check distinct output/opaque alpha, zero film strength, exposure response, monochrome channels, recipe serialization, invalid input, and actual JPEG/PNG/16-bit TIFF export/reload. Real camera RAW samples are still needed for camera-specific visual validation.

See [design and film research](Research/Design-and-film-notes.md) for the journey assumptions, alternative concepts, CSS extraction and primary sources.

## Branding and compatibility

The app is named Romeling Silverroom and bundles the supplied `romeling-logo.svg` unchanged. The header uses a template tint for contrast against the dark UI. The application identifier and Application Support directory remain unchanged so existing sessions and named recipes survive the rename. Missing new recipe fields decode with neutral defaults.

Creative effects are artistic treatments, not simulations of laboratory chemistry. Film strength controls emulsion rendering; the creative finish is independently applied afterward. Legacy halation compositing has been corrected to keep exported opacity and color consistent with previews.

Close a photograph using **×** on its thumbnail (**⌘⌫**). Original files stay on disk. The toolbar’s **More → Reset** menu can reset adjustments while keeping the selected film, or restore all default settings. **⌘Z** undoes both closing and resetting; **⇧⌘Z** redoes them.

## Package and publish

```sh
./scripts/build-dmg.sh
```

Creates the universal app, compressed DMG and `dist/SHA256SUMS.txt`. Build outputs are release assets, not committed binaries. The GitHub Pages site lives in `docs/` and deploys through `.github/workflows/pages.yml` on pushes to main. Update the version in `scripts/build-app.sh` and download links in `docs/index.html` together for a new release.

## Batch processing

Click **Batch** in the toolbar. Select any images in the current session, choose the current image’s film and adjustments for a consistent look or keep each image’s own settings, then choose JPEG, PNG or 16-bit TIFF and an output folder. Every run creates a new subfolder with numbered filenames. Session settings and source files stay unchanged.

Progress and per-file errors are shown as images process serially. **Stop batch** finishes the current image and skips the remaining queue; completed exports are kept. **Show exports** opens the output folder. Settings are captured when the batch starts.

## Preview and film controls

Use **Previous / Next** under the film name, or **⌥↑ / ⌥↓**, to cycle through the same maker/name order as the film browser. Plain **↑ / ↓** work when the preview or film selector is focused; they do not replace arrow-key editing in other controls. Film switching preserves your adjustments and supports undo.

Grain amount spans 0–800% (100% is the stock default), with size 0.5–8×. Existing recipes retain their appearance. Grain remains proportional to film strength; assess it at 100% zoom. Comparison split position can be dragged on the image or adjusted with the labeled toolbar slider. Side-by-side views share one scroll area for aligned panning.

## Reference image matching

Select **Color → Match a reference photograph…**, then **Choose reference…** to load a RAW or standard image. The app analyzes color averages, saturation and tonal percentiles locally, then searches bounded adjustments to exposure, warmth, tint, contrast, saturation, shadow lift and highlight recovery. Your film, grain and other effects remain intact.

Preview the reference and proposed result side by side, adjust **Match strength**, and toggle **Show before match**. **Apply match** commits one undoable adjustment; Cancel leaves the image unchanged. Fine-tune the resulting inspector settings, save a recipe or use the current look for batch export. No reference-file dependency is needed after applying.

This is a global statistical starting point, not subject-aware or exact color transfer. Different scene content affects the match, and the selected film can constrain it (for example, a monochrome film cannot reproduce a colorful reference).

## Film development and scanner stages (1.6)

Select **Light → Details → Film response & development**. **Exposure-aware response** introduces exposure-dependent saturation, color and highlight compression; slide interpretations have an earlier highlight shoulder. **Push / pull** spans −2 to +3 stops and couples contrast, shadow density, grain and color. It simulates development character; use Exposure separately to change brightness.

Under **Texture**, choose **35mm**, **120 / Medium format**, or **110 / Small format**, adjust **Image-aware grain** for tonal variation, and add **Grain color** for channel variation. Monochrome stocks retain monochrome grain. **Glow → Halation** offers amount and spread, with threshold, edge intensity and hue in Details. Enable Edge-aware halation to replace the legacy stock glow on every film.

**Color → Scanner & print** is a separate stage with Neutral scan, Warm minilab, Cool editorial and Soft print interpretations plus strength, contrast and sharpening. These are authored artistic looks, not measurements of a named film/scanner or chemical process. New controls default to neutral for older sessions.

## Local development

Select **Local**, add up to 16 named masks, and select a mask to edit it. Radial and gradient masks can be positioned on the Fit preview or with horizontal/vertical sliders. Brush masks paint and erase strokes; Size controls brush radius, and Feather softens the selection. Luminance selects pixels above a threshold; invert it to select shadows. Color range selects a hue band with adjustable width.

Each mask has enable/invert controls and local exposure, warmth, saturation, contrast and softness. **Show mask** overlays the selection in red for preview only; **Done placing** returns to normal interaction. Hide the overlay to judge the final result. Delete and painting operations support undo. Masks use normalized image coordinates and follow recipes into full-resolution export and batch processing. Brush masks are rasterized at up to 1024 pixels wide before scaling, so very small brush details can soften on large exports. Masks transfer geometrically in batch recipes; they do not detect subjects.

Reference matching now scores shadow/highlight color relationships as well as global color, saturation and tonal percentiles, while preserving the new film, scanner and mask settings.

## Working print controls (1.9)

The photograph fills the workspace beneath a standard-height native Mac toolbar. A rounded material inspector with an inset edge and subtle shadow holds the controls. Film rolls stay pinned at the top while adjustments scroll below. Click a roll or its previous/next arrows to switch; the grid button opens all films and favorites. Click the current film name to browse films, manage favorites, or expand live neighboring-film previews. **↑/↓** while the preview is focused and **⌥↑/⌥↓** cycle films. Choose **Light · Color · Texture · Glow · Local** from the adjustment selector in the resizable native inspector.

**⌥⌘I** toggles the inspector, and **⌥⌘S** toggles the session thumbnails (hidden by default). Both are also available in View and the toolbar. Hide both for a centered, unobstructed photograph. Versions, reset and batch export are in the toolbar’s **More** menu. **Explore** opens variations on demand rather than occupying the canvas.

- **Light:** exposure, bidirectional shadows/highlights, and contrast. **Adjust light on image** lets you drag up/down over the photograph. Auto chooses a tonal region from the original pixels at your starting point; Target allows an explicit region. These are whole-image tonal changes. Use Local for an area-specific correction.
- **Color:** balance, saturation, reference matching and scanner interpretation; expand Details for split tones, fading and cross-processing.
- **Texture:** grain amount, fine/coarse size and film format. A movable image target drives a **100% full-resolution loupe** without moving the main composition. Loupe sliders provide a keyboard alternative. Color and image-aware weighting remain under Grain details.
- **Glow:** separate Halation, Bloom and Light leak choices. Choose a bright image area to suggest a halation threshold and enable edge-aware rendering; drag sideways to set spread. Dark points leave settings unchanged. Stock halation remains available with edge-aware disabled. Light leaks retain direct placement.
- **Local:** named masks, visible geometry, explicit Paint/Erase, brush/feather cursor rings, basic local controls, and expandable precision controls. Escape finishes active image editing when the preview is focused.

**Explore** shows Less / Current / More previews for the current tool, with an adjustable step size. Choosing a preview commits one undoable change. Cancel leaves the recipe unchanged. For Light, variations change exposure; Color changes saturation; Texture changes grain; Glow changes halation amount; Local changes the selected mask’s exposure.

**Keep version** saves a settings snapshot for the current photograph. **Versions** compares a kept version against the current edit, restores it, or deletes it with undo. Versions persist with the session; they contain recipes, not copies of the original image. Zoomed side-by-side views use synchronized native scroll panes. B always returns to original/developed comparison.

**Preview off** temporarily bypasses the current tool without changing its settings. Export and Keep version are disabled until Return to edit; changing a setting also returns to the edit. **Reset [tool]** resets only that tool; Local reset preserves mask geometry and clears its adjustments. The main Reset menu also offers selected-mask adjustment reset and whole-look reset. Right-click a parameter to reset just that control. Numeric value fields accept your Mac’s locale and commit on Return.
