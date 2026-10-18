import XCTest
import CoreImage
import ImageIO
@testable import Silverroom

final class EngineTests: XCTestCase {
    func fixture() -> CIImage {
        let filter = CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 240, y: 160), "inputColor0": CIColor(red: 0.08, green: 0.2, blue: 0.4), "inputColor1": CIColor(red: 1, green: 0.8, blue: 0.4)])!
        return filter.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 240, height: 160))
    }
    func bytes(_ image: CIImage) throws -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 240 * 160 * 4)
        Engine.context.render(image, toBitmap: &result, rowBytes: 240 * 4, bounds: image.extent, format: .RGBA8, colorSpace: Engine.colorSpace)
        return result
    }
    func testEveryFilmProducesDistinctFiniteImage() throws {
        var hashes = Set<Data>()
        for film in Film.all {
            var recipe = Recipe(); recipe.filmID = film.id
            let result = Engine.develop(fixture(), recipe: recipe)
            XCTAssertEqual(result.extent, fixture().extent)
            let pixels = try bytes(result)
            XCTAssertTrue(pixels.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 255 })
            hashes.insert(Data(pixels))
        }
        XCTAssertEqual(hashes.count, Film.all.count)
    }
    func testZeroStrengthRemovesFilm() throws {
        var a = Recipe(); a.amount = 0
        var b = a; b.filmID = "800t"
        XCTAssertEqual(try bytes(Engine.develop(fixture(), recipe: a)), try bytes(Engine.develop(fixture(), recipe: b)))
    }
    func testExposureChangesLuminance() throws {
        var dark = Recipe(); dark.exposure = -1
        var light = Recipe(); light.exposure = 1
        let d = try bytes(Engine.develop(fixture(), recipe: dark)).map(Int.init).reduce(0, +)
        let l = try bytes(Engine.develop(fixture(), recipe: light)).map(Int.init).reduce(0, +)
        XCTAssertGreaterThan(l, d)
    }
    func testMonochromeHasEqualChannels() throws {
        var r = Recipe(); r.filmID = "hp5"
        let pixels = try bytes(Engine.develop(fixture(), recipe: r))
        for i in stride(from: 0, to: pixels.count, by: 4) { XCTAssertLessThanOrEqual(abs(Int(pixels[i]) - Int(pixels[i+1])), 1); XCTAssertLessThanOrEqual(abs(Int(pixels[i+1]) - Int(pixels[i+2])), 1) }
    }
    func testExportFormatsAndReload() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for format in ["jpg", "png", "tiff"] {
            let url = dir.appendingPathComponent("fixture." + format)
            try Engine.export(Engine.develop(fixture(), recipe: Recipe()), to: url, format: format)
            let loaded = try Engine.load(url)
            XCTAssertEqual(loaded.extent.size, fixture().extent.size)
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
            XCTAssertEqual(props[kCGImagePropertyDepth] as? Int, format == "tiff" ? 16 : 8)
        }
    }
    func testRecipeRoundTrip() throws {
        var r = Recipe(); r.filmID = "800t"; r.exposure = 1.25; r.halation = 0.4
        XCTAssertEqual(r, try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(r)))
    }
    func testInvalidImageFails() { XCTAssertThrowsError(try Engine.load(URL(fileURLWithPath: "/missing/photo.dng"))) }
}

extension EngineTests {
    func testLegacyRecipesKeepEditsAndGainNeutralDefaults() throws {
        let old = Data(#"{"filmID":"800t","amount":0.8,"exposure":1.25,"warmth":0.2,"tint":-0.1,"contrast":1.1,"saturation":0.9,"highlights":0.2,"shadows":0.3,"grain":1.4,"halation":0.5,"vignette":0.2}"#.utf8)
        let migrated = try JSONDecoder().decode(Recipe.self, from: old)
        XCTAssertEqual(migrated.exposure, 1.25)
        XCTAssertEqual(migrated.filmID, "800t")
        XCTAssertEqual(migrated.grain, 1.4)
        XCTAssertEqual(migrated.grainSize, 1)
        XCTAssertEqual(migrated.lightLeak, 0)
        XCTAssertEqual(migrated.crossProcess, 0)
        XCTAssertEqual(try bytes(Engine.creative(fixture(), recipe: migrated)), try bytes(fixture()))
    }
    func testCreativeControlsHaveVisibleEffects() throws {
        let baseline = try bytes(Engine.develop(fixture(), recipe: Recipe()))
        let edits: [(String, (inout Recipe) -> Void)] = [
            ("fade", { $0.fade = 0.8 }), ("black depth", { $0.blackPoint = 0.8 }),
            ("cross-process", { $0.crossProcess = 1 }), ("shadow color", { $0.shadowTone = 1 }),
            ("highlight color", { $0.highlightTone = 1 }), ("grain size", { $0.grainSize = 3 }),
            ("bloom", { $0.bloom = 1 }), ("leak", { $0.lightLeak = 0.8 })
        ]
        for (name, edit) in edits {
            var r = Recipe(); edit(&r)
            let image = Engine.develop(fixture(), recipe: r)
            let result = try bytes(image)
            XCTAssertEqual(image.extent, fixture().extent)
            XCTAssertNotEqual(result, baseline, name)
            XCTAssertTrue(result.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 255 }, name)
        }
    }
    func testSecondaryCreativeParametersAffectActiveEffect() throws {
        let pairs: [((inout Recipe) -> Void, (inout Recipe) -> Void)] = [
            ({ $0.shadowTone = 1 }, { $0.shadowHue = 0.1 }),
            ({ $0.highlightTone = 1 }, { $0.highlightHue = 0.65 }),
            ({ $0.bloom = 1 }, { $0.bloomRadius = 1 }),
            ({ $0.lightLeak = 1 }, { $0.leakHue = 0.7 }),
            ({ $0.lightLeak = 1 }, { $0.leakX = 0.9; $0.leakY = 0.9 }),
            ({ $0.lightLeak = 1 }, { $0.leakSize = 1 })
        ]
        for (activate, edit) in pairs {
            var a = Recipe(); activate(&a); var b = a; edit(&b)
            XCTAssertNotEqual(try bytes(Engine.develop(fixture(), recipe: a)), try bytes(Engine.develop(fixture(), recipe: b)))
        }
    }
    func testCreativeSettingsRoundTripAndExport() throws {
        var r = Recipe(); Treatment.sunwash.apply(to: &r)
        r.filmID = "purple"; r.grainSize = 2.4; r.shadowTone = 0.4; r.crossProcess = 0.3
        XCTAssertEqual(r, try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(r)))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        let rendered = Engine.develop(fixture(), recipe: r)
        try Engine.export(rendered, to: url, format: "png")
        let loaded = try Engine.load(url)
        XCTAssertEqual(loaded.extent, rendered.extent)
        let exported = try bytes(loaded), preview = try bytes(rendered)
        let maxError = zip(exported, preview).map { abs(Int($0) - Int($1)) }.max()!
        XCTAssertLessThanOrEqual(maxError, 2)
    }
    func testLightPositionUsesTopLeftCoordinates() throws {
        let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: fixture().extent)
        var r = Recipe(); r.lightLeak = 1; r.leakX = 0; r.leakY = 0; r.leakSize = 0
        let pixels = try bytes(Engine.creative(black, recipe: r))
        // CI bitmap output is top-first; normalized y=0 must brighten the top.
        let topLeft = Int(pixels[0]); let bottomLeft = Int(pixels[(159 * 240) * 4])
        XCTAssertGreaterThan(topLeft, bottomLeft + 50)
    }
    func testTreatmentsPreserveExposureAndFilm() {
        for treatment in Treatment.allCases {
            var r = Recipe(); r.filmID = "velvia50"; r.exposure = 1.25; r.warmth = 0.2; r.tint = -0.4
            treatment.apply(to: &r)
            XCTAssertEqual(r.filmID, "velvia50"); XCTAssertEqual(r.exposure, 1.25)
            XCTAssertEqual(r.warmth, 0.2); XCTAssertEqual(r.tint, -0.4)
        }
    }
}

extension EngineTests {
    func testEveryStockExportsLikeItsPreview() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for film in Film.all {
            var r = Recipe(); r.filmID = film.id
            let image = Engine.develop(fixture(), recipe: r)
            let url = dir.appendingPathComponent(film.id + ".png")
            try Engine.export(image, to: url, format: "png")
            let saved = try bytes(Engine.load(url)), preview = try bytes(image)
            let maxError = zip(saved, preview).map { abs(Int($0) - Int($1)) }.max()!
            XCTAssertLessThanOrEqual(maxError, 2, film.name)
        }
    }
}

extension EngineTests {
    func testColorFieldAxesMatchTheirLabels() throws {
        let gray = CIImage(color: CIColor(red: 0.4, green: 0.4, blue: 0.4)).cropped(to: fixture().extent)
        var warm = Recipe(); warm.amount = 0; warm.warmth = 1
        let w = try bytes(Engine.develop(gray, recipe: warm))
        XCTAssertGreaterThan(w[0], w[2], "Warm axis should favor red over blue")
        var magenta = Recipe(); magenta.amount = 0; magenta.tint = 1
        let m = try bytes(Engine.develop(gray, recipe: magenta))
        XCTAssertGreaterThan((Int(m[0]) + Int(m[2])) / 2, Int(m[1]), "Magenta axis should favor red/blue over green")
    }
    func testExtendedGrainAddsTextureWithoutChangingOpacity() throws {
        let flat = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 240, height: 160))
        var recipe = Recipe(); recipe.grain = 0; recipe.halation = 0
        let clean = try bytes(Engine.develop(flat, recipe: recipe))
        recipe.grain = 2
        let normal = try bytes(Engine.develop(flat, recipe: recipe))
        recipe.grain = 8; recipe.grainSize = 8
        let strong = try bytes(Engine.develop(flat, recipe: recipe))
        func difference(_ values: [UInt8]) -> Int { zip(values, clean).enumerated().filter { $0.offset % 4 != 3 }.reduce(0) { $0 + abs(Int($1.element.0) - Int($1.element.1)) } }
        XCTAssertGreaterThan(difference(strong), difference(normal))
        XCTAssertTrue(strong.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 255 })
        XCTAssertEqual(try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe)), recipe)
    }

}
