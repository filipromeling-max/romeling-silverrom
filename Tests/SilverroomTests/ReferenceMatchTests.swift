import XCTest
import CoreImage
@testable import Silverroom

final class ReferenceMatchTests: XCTestCase {
    func fixture() -> CIImage {
        CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 100, y: 80), "inputColor0": CIColor(red: 0.1, green: 0.2, blue: 0.3), "inputColor1": CIColor(red: 0.8, green: 0.6, blue: 0.4)])!.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: 100, height: 80))
    }
    func testSuggestionImprovesMatchAndPreservesTexture() throws {
        let source = fixture()
        var base = Recipe(); base.grain = 3; base.grainSize = 2
        var target = base; target.exposure = 0.6; target.warmth = 0.3; target.saturation = 0.65
        let reference = Engine.develop(source, recipe: target)
        let suggestion = try ReferenceMatcher.suggest(source: source, reference: reference, base: base)
        let signature = try ReferenceMatcher.signature(reference)
        let before = try ReferenceMatcher.distance(ReferenceMatcher.signature(Engine.develop(source, recipe: base)), signature)
        let after = try ReferenceMatcher.distance(ReferenceMatcher.signature(Engine.develop(source, recipe: suggestion)), signature)
        XCTAssertLessThan(after, before)
        XCTAssertEqual(suggestion.filmID, base.filmID)
        XCTAssertEqual(suggestion.grain, base.grain); XCTAssertEqual(suggestion.grainSize, base.grainSize)
        XCTAssertEqual(suggestion.lightLeak, base.lightLeak)
        for (key, bounds, _) in ReferenceMatcher.parameters { XCTAssertTrue(bounds.contains(suggestion[keyPath: key])) }
        XCTAssertEqual(ReferenceMatcher.blend(base: base, suggestion: suggestion, strength: 0), base)
        XCTAssertEqual(ReferenceMatcher.blend(base: base, suggestion: suggestion, strength: 1), suggestion)
        XCTAssertEqual(try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(suggestion)), suggestion)
    }
    func testTransparentReferenceFailsAndBlackReferenceIsFinite() throws {
        let transparent = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10))
        XCTAssertThrowsError(try ReferenceMatcher.signature(transparent))
        let black = CIImage(color: .black).cropped(to: transparent.extent)
        XCTAssertTrue(try ReferenceMatcher.signature(black).allSatisfy(\.isFinite))
    }
}
