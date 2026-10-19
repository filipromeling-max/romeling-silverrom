import SwiftUI
import CoreImage

enum PrintTool: String, CaseIterable, Codable {
    case light = "Light", color = "Color", texture = "Texture", glow = "Glow", local = "Local"
    var symbol: String {
        switch self { case .light: return "sun.max"; case .color: return "circle.lefthalf.filled"; case .texture: return "circle.dotted"; case .glow: return "sparkles"; case .local: return "paintbrush.pointed" }
    }
    func reset(_ recipe: Recipe) -> Recipe {
        let defaults = Recipe()
        var result = recipe
        let keys: [WritableKeyPath<Recipe, Double>]
        switch self {
        case .light:
            keys = [\.exposure, \.contrast, \.shadows, \.highlights, \.shadowBalance, \.highlightBalance, \.development.response, \.development.pushPull]
        case .color:
            keys = [\.warmth, \.tint, \.saturation, \.fade, \.blackPoint, \.crossProcess, \.shadowTone, \.shadowHue, \.highlightTone, \.highlightHue, \.development.scannerStrength, \.development.scanContrast, \.development.scanSharpness]
            result.development.scanner = "neutral"
        case .texture:
            keys = [\.grain, \.grainSize, \.development.adaptiveGrain, \.development.grainColor]
            result.development.format = "35mm"
        case .glow:
            keys = [\.halation, \.bloom, \.bloomRadius, \.lightLeak, \.leakX, \.leakY, \.leakSize, \.leakHue, \.vignette, \.development.advancedHalation, \.development.halationSpread, \.development.halationThreshold, \.development.halationHue]
        case .local:
            keys = []
            result.masks = result.masks.map { mask in
                var value = mask
                value.exposure = 0; value.warmth = 0; value.saturation = 1; value.contrast = 1; value.softness = 0
                return value
            }
        }
        for key in keys { result[keyPath: key] = defaults[keyPath: key] }
        return result
    }
    func bypass(_ recipe: Recipe) -> Recipe {
        var result = reset(recipe)
        if self == .texture { result.grain = 0 }
        if self == .glow { result.halation = 0 }
        if self == .local { result.masks = [] }
        return result
    }
    func variation(_ recipe: Recipe, direction: Double, step: Double, maskID: UUID?) -> Recipe {
        var value = recipe
        let delta = direction * step
        switch self {
        case .light: value.exposure = min(3, max(-3, value.exposure + delta * 0.4))
        case .color: value.saturation = min(2, max(0, value.saturation + delta * 0.25))
        case .texture: value.grain = min(8, max(0, value.grain + delta * 0.7))
        case .glow: value.halation = min(2, max(0, value.halation + delta * 0.4))
        case .local:
            if let i = value.masks.firstIndex(where: { $0.id == maskID }) { value.masks[i].exposure = min(3, max(-3, value.masks[i].exposure + delta * 0.4)) }
        }
        return value
    }
}
struct KeptVersion: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var recipe: Recipe
}
enum LightRegion: String, CaseIterable {
    case exposure = "Exposure", shadows = "Shadows", highlights = "Highlights"
    var key: WritableKeyPath<Recipe, Double> { switch self { case .exposure: return \.exposure; case .shadows: return \.shadowBalance; case .highlights: return \.highlightBalance } }
    var bounds: ClosedRange<Double> { self == .exposure ? -3...3 : -1...1 }
}
enum GlowTool: String, CaseIterable { case halation = "Halation", bloom = "Bloom", leak = "Light leak" }

extension Library {
    var filmChoices: [Film] {
        let all = Self.orderedFilms
        return favoritesOnly && !favoriteFilms.isEmpty ? all.filter { favoriteFilms.contains($0.id) } : all
    }
    var ribbonFilms: [Film] {
        let films = filmChoices
        guard let index = films.firstIndex(where: { $0.id == recipe.filmID }) else { return [recipe.film] + films.prefix(2) }
        if films.count < 3 { return films }
        return [-1, 0, 1].map { films[(index + $0 + films.count) % films.count] }
    }
    var displayedRecipe: Recipe { bypassedTool?.bypass(recipe) ?? recipe }
    var referenceName: String { selected?.versions.first { $0.id == comparisonVersionID }?.name ?? "Original" }
    var comparisonImage: NSImage? { comparisonVersionID == nil ? original : versionPreview }
    var canExport: Bool { canEdit && bypassedTool == nil }
    func chooseTool(_ tool: PrintTool) {
        activeTool = tool; bypassedTool = nil; explorationBase = nil
        editingMask = false; placingLight = false; showMask = false
        directAdjustment = false
        render()
    }
    func resetTool() {
        adjustmentGesture(false)
        change { $0 = activeTool.reset($0) }
    }
    func startDirectAdjustment() {
        directAdjustment.toggle(); editingMask = false; placingLight = false
        if directAdjustment { comparisonMode = .developed; comparisonVersionID = nil; zoom = false }
    }
    func pickLuminance(_ point: MaskPoint) -> Double? {
        guard let cg = original?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cg)
        let x = min(cg.width - 1, max(0, Int(point.x * Double(cg.width))))
        let y = min(cg.height - 1, max(0, Int(point.y * Double(cg.height))))
        guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return nil }
        return c.redComponent * 0.2126 + c.greenComponent * 0.7152 + c.blueComponent * 0.0722
    }
}
