import XCTest
import CoreImage
@testable import Silverroom

extension EngineTests {
    func testNewStagesAreNeutralForLegacyRecipes() throws {
        let decoded = try JSONDecoder().decode(Recipe.self, from: Data("{\"filmID\":\"portra400\",\"exposure\":1}".utf8))
        XCTAssertEqual(decoded.development, Development()); XCTAssertTrue(decoded.masks.isEmpty)
        var fresh = Recipe(); fresh.exposure = 1
        XCTAssertEqual(try bytes(Engine.develop(fixture(), recipe: decoded)), try bytes(Engine.develop(fixture(), recipe: fresh)))
    }
    func testResponseIsExposureDependentAndPushPullIsNotExposure() throws {
        var r = Recipe(); r.grain = 0; r.halation = 0
        let neutral = try bytes(Engine.develop(fixture(), recipe: r))
        r.development.response = 1
        XCTAssertEqual(try bytes(Engine.develop(fixture(), recipe: r)), neutral)
        r.exposure = 1.5
        let response = try bytes(Engine.develop(fixture(), recipe: r))
        r.development.response = 0
        XCTAssertNotEqual(try bytes(Engine.develop(fixture(), recipe: r)), response)
        r.exposure = 0; r.development.pushPull = 2
        let pushed = try bytes(Engine.develop(fixture(), recipe: r))
        r.development.pushPull = -2
        XCTAssertNotEqual(pushed, try bytes(Engine.develop(fixture(), recipe: r)))
        r.development.pushPull = 0; r.exposure = 2
        XCTAssertNotEqual(pushed, try bytes(Engine.develop(fixture(), recipe: r)))
    }
    func testAdaptiveGrainFormatAndColorChangeTexture() throws {
        var r = Recipe(); r.grain = 5
        let old = try bytes(Engine.develop(fixture(), recipe: r))
        r.development.adaptiveGrain = 1
        let adaptive = try bytes(Engine.develop(fixture(), recipe: r))
        XCTAssertNotEqual(old, adaptive)
        r.development.format = "120"
        XCTAssertNotEqual(adaptive, try bytes(Engine.develop(fixture(), recipe: r)))
        r.development.format = "35mm"; r.development.grainColor = 1
        XCTAssertNotEqual(adaptive, try bytes(Engine.develop(fixture(), recipe: r)))
    }
    func testHalationNeedsBrightEdgesAndHasSpreadHueThresholdControls() throws {
        var r = Recipe(); r.filmID = "velvia50"; r.grain = 0; r.development.advancedHalation = 1
        let base = CIImage(color: CIColor(red: 0.05, green: 0.05, blue: 0.05)).cropped(to: fixture().extent)
        let patch = CIImage(color: .white).cropped(to: CGRect(x: 100, y: 55, width: 40, height: 50)).composited(over: base)
        let halo = try bytes(Engine.develop(patch, recipe: r))
        r.development.halationHue = 0.6
        XCTAssertNotEqual(halo, try bytes(Engine.develop(patch, recipe: r)))
        r.development.halationSpread = 0.9
        XCTAssertNotEqual(halo, try bytes(Engine.develop(patch, recipe: r)))
        r.development.halationThreshold = 0.95
        XCTAssertNotEqual(halo, try bytes(Engine.develop(patch, recipe: r)))
        let flat = CIImage(color: CIColor(red: 0.8, green: 0.8, blue: 0.8)).cropped(to: fixture().extent)
        let flatWithHalo = try bytes(Engine.develop(flat, recipe: r))
        r.development.advancedHalation = 0
        XCTAssertEqual(flatWithHalo, try bytes(Engine.develop(flat, recipe: r)))
    }
    func testScannerVariantsAndSharpeningAreIndependentOfFilm() throws {
        var r = Recipe(); r.grain = 0; r.halation = 0
        let baseline = try bytes(Engine.develop(fixture(), recipe: r))
        var variants = Set<Data>()
        for scanner in ["neutral", "minilab", "editorial", "print"] {
            r.development.scanner = scanner
            variants.insert(Data(try bytes(Engine.develop(fixture(), recipe: r))))
            XCTAssertEqual(r.filmID, "portra400")
        }
        XCTAssertEqual(variants.count, 4)
        r.development.scannerStrength = 0
        XCTAssertTrue(baseline == (try bytes(Engine.develop(fixture(), recipe: r))))
        r.development.scanSharpness = 1
        XCTAssertNotEqual(baseline, try bytes(Engine.develop(fixture(), recipe: r)))
    }
    func testMaskCoordinatesInversionAndLocality() throws {
        let flat = CIImage(color: CIColor(red: 0.25, green: 0.25, blue: 0.25)).cropped(to: fixture().extent)
        var mask = LocalMask(); mask.x = 0.2; mask.y = 0.2; mask.radius = 0.12; mask.exposure = 2
        let rendered = try bytes(Engine.localDevelop(flat, masks: [mask]))
        func pixel(_ values: [UInt8], _ x: Int, _ y: Int) -> Int { Int(values[(y * 240 + x) * 4]) }
        XCTAssertGreaterThan(pixel(rendered, 48, 32), pixel(rendered, 200, 20) + 30)
        mask.inverted = true
        let inverse = try bytes(Engine.localDevelop(flat, masks: [mask]))
        XCTAssertGreaterThan(pixel(inverse, 200, 20), pixel(inverse, 48, 32) + 30)
        mask.enabled = false
        XCTAssertEqual(try bytes(flat), try bytes(Engine.localDevelop(flat, masks: [mask])))
    }
    func testEveryMaskTypeRendersAndBrushEraseWorks() throws {
        var hashes = Set<Data>()
        for kind in MaskKind.allCases {
            var mask = LocalMask(); mask.kind = kind; mask.exposure = 1
            mask.strokes = [MaskStroke(points: [MaskPoint(x: 0.2, y: 0.2), MaskPoint(x: 0.7, y: 0.7)])]
            let pixels = try bytes(Engine.localDevelop(fixture(), masks: [mask]))
            hashes.insert(Data(pixels))
            XCTAssertTrue(pixels.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 255 })
        }
        XCTAssertEqual(hashes.count, MaskKind.allCases.count)
        var brush = LocalMask(); brush.kind = .brush; brush.radius = 0.1; brush.feather = 0
        let point = MaskPoint(x: 0.5, y: 0.5)
        brush.strokes = [MaskStroke(points: [point])]
        let painted = try bytes(Engine.localMask(brush, image: fixture()))
        brush.strokes.append(MaskStroke(points: [point], erase: true))
        let erased = try bytes(Engine.localMask(brush, image: fixture()))
        XCTAssertGreaterThan(painted.map(Int.init).reduce(0,+), erased.map(Int.init).reduce(0,+))
    }
    func testAdvancedRecipeRoundTripAndExport() throws {
        var r = Recipe(); r.development.response = 1; r.development.pushPull = 1
        r.development.adaptiveGrain = 1; r.development.grainColor = 0.3; r.development.format = "120"
        r.development.advancedHalation = 0.7; r.development.scanner = "minilab"; r.development.scanSharpness = 0.8
        var mask = LocalMask(); mask.kind = .gradient; mask.exposure = -0.7; r.masks = [mask]
        let decoded = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(decoded, r)
        let image = Engine.develop(fixture(), recipe: r)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for format in ["png", "tiff", "jpg"] {
            let url = directory.appendingPathComponent("advanced." + format)
            try Engine.export(image, to: url, format: format)
            let reloaded = try Engine.load(url)
            XCTAssertEqual(reloaded.extent, image.extent)
            if format == "png" {
                let error = zip(try bytes(reloaded), try bytes(image)).map { abs(Int($0) - Int($1)) }.max()!
                XCTAssertLessThanOrEqual(error, 2)
            }
        }
    }
}
