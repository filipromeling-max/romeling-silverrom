# Controls review — 1.4.0

Applied UI/UX Pro Max guidance to the existing native SwiftUI/AppKit darkroom. The supplied skill contains guidance, not a searchable style database.

## Observed issues and changes

- The close-image X was next to zoom, making an unrelated action easy to hit. Removed it from the image header; retained thumbnail closing and the Develop command.
- Comparison only supported a fixed halfway split. Added original/developed, vertical and horizontal splits, and side-by-side. Splits offer both a draggable surface and a labeled keyboard-accessible slider.
- Zoom only toggled Fit/100%. Added bounded 25–400% presets, plus/minus controls, Fit and keyboard commands. Full-resolution rendering is reused when stepping between numeric zoom levels. Scroll pans oversized images.
- Film changes required reopening the library. Added Previous/Next buttons and focus-scoped arrow handling, plus Option-arrow menu shortcuts. Order matches the film browser and wraps. Other adjustments remain unchanged and each film change supports undo.
- Grain was limited to 200% and 4× size. Expanded to 800% and 8×, retained old recipe values, and clamped noise opacity. Grain controls start expanded; light effects start collapsed. Added guidance to inspect grain at 100%.
- Small sliders used mini controls. Switched to small native sliders and 12-point labels. Removed the duplicate immediate Reset all action from the inspector; the explicit Reset menu remains in the image header.

## Verification

24 automated tests pass, including increased grain texture/opacity, film navigation/wrap/undo, zoom bounds, batch export and legacy recipes. Native UI checks confirm plain up/down film switching, side-by-side comparison, horizontal split and accessible divider adjustment, and 100% scrollable zoom. Visual inspection confirms separated controls and image alignment at the current window size. This is not an accessibility-compliance audit. Intel builds compile; interactive testing uses Apple silicon.
