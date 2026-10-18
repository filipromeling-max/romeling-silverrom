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
2. Click the selected film to search **20 stocks** by maker/name, or filter Color, Monochrome and Experimental. Kodak: Portra 160/400/800, Gold 200, UltraMax 400, Ektar 100, Ektachrome E100, Tri-X 400, T-Max 100. Fujifilm: Velvia 50, Provia 100F. CineStill: 50D, 400D, 800T. Ilford: HP5 Plus, Delta 100/3200, Pan F Plus. Lomography: LomoChrome Purple, Metropolis.
3. Drag **Color balance** to change warmth and tint together, or expand Precision controls for individual keyboard-accessible sliders. Develop tone and saturation, add split toning, faded blacks, black depth, or cross-processing. Change grain amount/size, halation, bloom/spread, and vignette.
4. Add a **light leak**, then click **Place light on photograph** to drag its origin directly over the image. Hue, spread and precise position remain adjustable in the inspector. Placement switches to the developed image at fit size; Compare or 100% exits placement.
5. Try **Amber & cyan**, **Faded print**, **Nocturne**, or **Sun wash** from the treatment menu. These replace the creative finishing settings while preserving the chosen film, exposure and white balance. **Clean finish** resets that same finishing subset; **Reset all** restores the full default recipe.
6. Use **Compare** for original-only, vertical/horizontal draggable splits, or side-by-side views. **B** toggles original/developed. **⌘0** fits the image, **⌘1** toggles fit/100%, and **⌘− / ⌘=** step zoom from 25% to 400%. Scroll to pan. Double-click the preview in Developed or Original mode to toggle fit/100%.
7. Save a named recipe or export a full-resolution JPEG (95%), PNG (8-bit), or TIFF (16-bit), tagged sRGB. **⇧⌘E** exports JPEG.

**⌘Z / ⇧⌘Z** undo/redo. Develop menu closes an image from the session without deleting the source. The session and recipes automatically save to `~/Library/Application Support/Silverroom/`. Originals are never edited. Referenced files need to remain accessible at their original location. Exports contain rendered pixels and color profiles; source EXIF/IPTC metadata is not copied.

## Honest boundaries

Film profiles are researched creative approximations, not calibrated reproductions. RAW compatibility is provided by Apple's CIRAWFilter and varies by camera and installed macOS. Unsupported RAW files produce an error instead of silently using an embedded JPEG. Preview is downsampled to 1800 pixels; 100% and export render full resolution. Grain is approximate and may look different at fit size. This version supports individual and batch export. It does not include crop, local masks, lens profiles, or an archival catalog.

## Validation

```sh
swift test
```

Tests render all twenty films, check distinct output/opaque alpha, zero film strength, exposure response, monochrome channels, recipe serialization, invalid input, and actual JPEG/PNG/16-bit TIFF export/reload. Real camera RAW samples are still needed for camera-specific visual validation.

See [design and film research](Research/Design-and-film-notes.md) for the journey assumptions, alternative concepts, CSS extraction and primary sources.

## Branding and compatibility

The app is named Romeling Silverroom and bundles the supplied `romeling-logo.svg` unchanged. The header uses a template tint for contrast against the dark UI. The application identifier and Application Support directory remain unchanged so existing sessions and named recipes survive the rename. Missing new recipe fields decode with neutral defaults.

Creative effects are artistic treatments, not simulations of laboratory chemistry. Film strength controls emulsion rendering; the creative finish is independently applied afterward. Legacy halation compositing has been corrected to keep exported opacity and color consistent with previews.

Close a photograph using **×** on its thumbnail (**⌘⌫**). Original files stay on disk. The toolbar’s **Reset** menu can reset adjustments while keeping the selected film, or restore all default settings. **⌘Z** undoes both closing and resetting; **⇧⌘Z** redoes them.

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
