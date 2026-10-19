import Foundation

struct Film: Identifiable, Hashable {
    let id: String
    let maker: String
    let name: String
    let iso: String
    let kind: String
    let note: String
    let color: UInt32
    let saturation: Double
    let contrast: Double
    let warmth: Double
    let tint: Double
    let fade: Double
    let grain: Double
    let halation: Double
    var monochrome: Bool { kind == "BLACK & WHITE" }
    static let all: [Film] = [
        Film(id: "portra400", maker: "KODAK", name: "Portra 400", iso: "400", kind: "COLOR NEGATIVE", note: "Gentle color. Natural skin. An unhurried, versatile negative.", color: 0xC8A56E, saturation: 0.94, contrast: 0.96, warmth: 0.10, tint: 0.02, fade: 0.025, grain: 0.24, halation: 0.04),
        Film(id: "portra160", maker: "KODAK", name: "Portra 160", iso: "160", kind: "COLOR NEGATIVE", note: "Subtle color and a fine, smooth texture for portraits and soft light.", color: 0xD1BC91, saturation: 0.91, contrast: 0.94, warmth: 0.07, tint: 0.015, fade: 0.02, grain: 0.12, halation: 0.02),
        Film(id: "ektar100", maker: "KODAK", name: "Ektar 100", iso: "100", kind: "COLOR NEGATIVE", note: "Vivid color, defined contrast, and exceptionally fine grain.", color: 0xBD6454, saturation: 1.23, contrast: 1.09, warmth: 0.04, tint: 0.015, fade: 0.005, grain: 0.08, halation: 0.02),
        Film(id: "velvia50", maker: "FUJIFILM", name: "Velvia 50", iso: "50", kind: "COLOR REVERSAL", note: "Rich greens and vivid color with the depth of a reversal film.", color: 0x85A884, saturation: 1.34, contrast: 1.16, warmth: -0.03, tint: 0.025, fade: 0, grain: 0.08, halation: 0),
        Film(id: "provia100", maker: "FUJIFILM", name: "Provia 100F", iso: "100", kind: "COLOR REVERSAL", note: "Balanced color, crisp detail, and a composed slide-film contrast.", color: 0x83A8AB, saturation: 1.10, contrast: 1.07, warmth: -0.025, tint: 0, fade: 0.003, grain: 0.09, halation: 0),
        Film(id: "800t", maker: "CINESTILL", name: "800T", iso: "800", kind: "TUNGSTEN NEGATIVE", note: "Cool daylight rendering and warm halation around bright lights.", color: 0xBC7762, saturation: 0.94, contrast: 1.02, warmth: -0.23, tint: -0.025, fade: 0.025, grain: 0.38, halation: 0.65),
        Film(id: "50d", maker: "CINESTILL", name: "50D", iso: "50", kind: "DAYLIGHT NEGATIVE", note: "Fine texture, daylight balance, and a subtle glow in highlights.", color: 0xD1B87A, saturation: 1.03, contrast: 0.98, warmth: 0.025, tint: 0, fade: 0.015, grain: 0.08, halation: 0.25),
        Film(id: "hp5", maker: "ILFORD", name: "HP5 Plus", iso: "400", kind: "BLACK & WHITE", note: "A flexible monochrome negative with open midtones and visible texture.", color: 0xA6ADA5, saturation: 0, contrast: 1.05, warmth: 0, tint: 0, fade: 0.015, grain: 0.36, halation: 0),
        Film(id: "gold200", maker: "KODAK", name: "Gold 200", iso: "200", kind: "COLOR NEGATIVE", note: "Sunlit warmth, lively everyday color, and familiar negative texture.", color: 0xD4AD52, saturation: 1.13, contrast: 1.04, warmth: 0.23, tint: -0.01, fade: 0.018, grain: 0.23, halation: 0.035),
        Film(id: "ultramax400", maker: "KODAK", name: "UltraMax 400", iso: "400", kind: "COLOR NEGATIVE", note: "Bright color and more visible texture for an everyday snapshot feel.", color: 0xD7AA69, saturation: 1.18, contrast: 1.07, warmth: 0.12, tint: -0.02, fade: 0.012, grain: 0.34, halation: 0.04),
        Film(id: "portra800", maker: "KODAK", name: "Portra 800", iso: "800", kind: "COLOR NEGATIVE", note: "Warm, natural color with a softer shoulder and a little more texture.", color: 0xBA9A77, saturation: 0.98, contrast: 0.97, warmth: 0.13, tint: 0.025, fade: 0.028, grain: 0.37, halation: 0.06),
        Film(id: "e100", maker: "KODAK", name: "Ektachrome E100", iso: "100", kind: "COLOR REVERSAL", note: "Clean whites, a neutral palette, and finely defined slide-film detail.", color: 0x88A9C4, saturation: 1.08, contrast: 1.1, warmth: -0.04, tint: 0.01, fade: 0.002, grain: 0.065, halation: 0),
        Film(id: "trix400", maker: "KODAK", name: "Tri-X 400", iso: "400", kind: "BLACK & WHITE", note: "A graphic monochrome interpretation with firm contrast and classic grain.", color: 0xB6AC8B, saturation: 0, contrast: 1.18, warmth: 0, tint: 0, fade: 0.008, grain: 0.46, halation: 0),
        Film(id: "tmax100", maker: "KODAK", name: "T-Max 100", iso: "100", kind: "BLACK & WHITE", note: "Fine, restrained texture with clear tonal separation and clean detail.", color: 0xA7A8AD, saturation: 0, contrast: 1.08, warmth: 0, tint: 0, fade: 0.004, grain: 0.09, halation: 0),
        Film(id: "delta100", maker: "ILFORD", name: "Delta 100", iso: "100", kind: "BLACK & WHITE", note: "Smooth monochrome gradation and a finely resolved, modern texture.", color: 0xB1B6B8, saturation: 0, contrast: 1.04, warmth: 0, tint: 0, fade: 0.006, grain: 0.11, halation: 0),
        Film(id: "delta3200", maker: "ILFORD", name: "Delta 3200", iso: "3200", kind: "BLACK & WHITE", note: "Expressive low-light texture and a broad, gentle monochrome scale.", color: 0xB2AFA4, saturation: 0, contrast: 0.98, warmth: 0, tint: 0, fade: 0.024, grain: 0.72, halation: 0),
        Film(id: "panf50", maker: "ILFORD", name: "Pan F Plus", iso: "50", kind: "BLACK & WHITE", note: "Very fine grain and assertive tonal contrast for deliberate light.", color: 0xB6B8A1, saturation: 0, contrast: 1.15, warmth: 0, tint: 0, fade: 0.002, grain: 0.065, halation: 0),
        Film(id: "400d", maker: "CINESTILL", name: "400D", iso: "400", kind: "DAYLIGHT NEGATIVE", note: "Soft daylight color, warm skin, and a gentle halo around bright light.", color: 0xC69B81, saturation: 1.02, contrast: 0.95, warmth: 0.09, tint: 0.01, fade: 0.023, grain: 0.25, halation: 0.4),
        Film(id: "purple", maker: "LOMOGRAPHY", name: "LomoChrome Purple", iso: "100–400", kind: "EXPERIMENTAL COLOR", note: "A surreal interpretation that turns green foliage toward violet.", color: 0xAD82C5, saturation: 1.1, contrast: 1.06, warmth: -0.02, tint: 0.12, fade: 0.012, grain: 0.3, halation: 0.03),
        Film(id: "metropolis", maker: "LOMOGRAPHY", name: "LomoChrome Metropolis", iso: "100–400", kind: "EXPERIMENTAL COLOR", note: "Muted color, hard contrast, and red accents in an urban palette.", color: 0x9FAD94, saturation: 0.65, contrast: 1.19, warmth: -0.06, tint: -0.08, fade: 0.018, grain: 0.38, halation: 0.03)
    ]
}

struct Recipe: Codable, Equatable {
    var filmID = "portra400"
    var amount = 1.0
    var exposure = 0.0
    var warmth = 0.0
    var tint = 0.0
    var contrast = 1.0
    var saturation = 1.0
    var highlights = 0.0
    var shadows = 0.0
    var grain = 1.0
    var halation = 1.0
    var vignette = 0.0
    var grainSize = 1.0
    var fade = 0.0
    var blackPoint = 0.0
    var crossProcess = 0.0
    var shadowHue = 0.55
    var shadowTone = 0.0
    var highlightHue = 0.10
    var highlightTone = 0.0
    var bloom = 0.0
    var bloomRadius = 0.35
    var lightLeak = 0.0
    var leakX = 0.05
    var leakY = 0.35
    var leakSize = 0.5
    var leakHue = 0.06
    var development = Development()
    var masks: [LocalMask] = []
    var film: Film { Film.all.first { $0.id == filmID } ?? Film.all[0] }
    init() {}

    // Older sessions omit the new controls. Neutral defaults preserve their edits.
    enum CodingKeys: String, CodingKey {
        case development, masks
        case filmID, amount, exposure, warmth, tint, contrast, saturation, highlights, shadows, grain, halation, vignette, grainSize, fade, blackPoint, crossProcess, shadowHue, shadowTone, highlightHue, highlightTone, bloom, bloomRadius, lightLeak, leakX, leakY, leakSize, leakHue
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        development = try values.decodeIfPresent(Development.self, forKey: .development) ?? Development()
        masks = try values.decodeIfPresent([LocalMask].self, forKey: .masks) ?? []
        filmID = try values.decodeIfPresent(String.self, forKey: .filmID) ?? "portra400"
        amount = try values.decodeIfPresent(Double.self, forKey: .amount) ?? 1.0
        exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? 0.0
        warmth = try values.decodeIfPresent(Double.self, forKey: .warmth) ?? 0.0
        tint = try values.decodeIfPresent(Double.self, forKey: .tint) ?? 0.0
        contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 1.0
        saturation = try values.decodeIfPresent(Double.self, forKey: .saturation) ?? 1.0
        highlights = try values.decodeIfPresent(Double.self, forKey: .highlights) ?? 0.0
        shadows = try values.decodeIfPresent(Double.self, forKey: .shadows) ?? 0.0
        grain = try values.decodeIfPresent(Double.self, forKey: .grain) ?? 1.0
        halation = try values.decodeIfPresent(Double.self, forKey: .halation) ?? 1.0
        vignette = try values.decodeIfPresent(Double.self, forKey: .vignette) ?? 0.0
        grainSize = try values.decodeIfPresent(Double.self, forKey: .grainSize) ?? 1.0
        fade = try values.decodeIfPresent(Double.self, forKey: .fade) ?? 0.0
        blackPoint = try values.decodeIfPresent(Double.self, forKey: .blackPoint) ?? 0.0
        crossProcess = try values.decodeIfPresent(Double.self, forKey: .crossProcess) ?? 0.0
        shadowHue = try values.decodeIfPresent(Double.self, forKey: .shadowHue) ?? 0.55
        shadowTone = try values.decodeIfPresent(Double.self, forKey: .shadowTone) ?? 0.0
        highlightHue = try values.decodeIfPresent(Double.self, forKey: .highlightHue) ?? 0.10
        highlightTone = try values.decodeIfPresent(Double.self, forKey: .highlightTone) ?? 0.0
        bloom = try values.decodeIfPresent(Double.self, forKey: .bloom) ?? 0.0
        bloomRadius = try values.decodeIfPresent(Double.self, forKey: .bloomRadius) ?? 0.35
        lightLeak = try values.decodeIfPresent(Double.self, forKey: .lightLeak) ?? 0.0
        leakX = try values.decodeIfPresent(Double.self, forKey: .leakX) ?? 0.05
        leakY = try values.decodeIfPresent(Double.self, forKey: .leakY) ?? 0.35
        leakSize = try values.decodeIfPresent(Double.self, forKey: .leakSize) ?? 0.5
        leakHue = try values.decodeIfPresent(Double.self, forKey: .leakHue) ?? 0.06
    }
}
struct SavedRecipe: Identifiable, Codable {
    var id = UUID()
    var name: String
    var recipe: Recipe
}
struct PhotoRecord: Codable {
    var path: String
    var recipe: Recipe
}
