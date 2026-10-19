import XCTest
import AppKit
@testable import Silverroom

final class WorkingPrintTests: XCTestCase {
    func testScopedResetAndBypassKeepOtherWork() {
        var recipe = Recipe(); recipe.exposure = 1; recipe.shadowBalance = 0.4; recipe.saturation = 0.7
        recipe.grain = 6; recipe.halation = 1.8; recipe.filmID = "800t"
        var mask = LocalMask(); mask.exposure = 1.2; mask.x = 0.3; recipe.masks = [mask]
        let light = PrintTool.light.reset(recipe)
        XCTAssertEqual(light.exposure, 0); XCTAssertEqual(light.shadowBalance, 0)
        XCTAssertEqual(light.saturation, 0.7); XCTAssertEqual(light.grain, 6); XCTAssertEqual(light.masks, recipe.masks)
        XCTAssertEqual(PrintTool.texture.bypass(recipe).grain, 0)
        XCTAssertEqual(PrintTool.glow.bypass(recipe).halation, 0)
        XCTAssertEqual(PrintTool.local.bypass(recipe).masks.count, 0)
        let local = PrintTool.local.reset(recipe)
        XCTAssertEqual(local.masks[0].x, 0.3); XCTAssertEqual(local.masks[0].exposure, 0)
        XCTAssertEqual(local.filmID, recipe.filmID); XCTAssertEqual(local.exposure, recipe.exposure)
    }
    func testExploreIsBoundedAndPreservesUnrelatedFields() {
        var recipe = Recipe(); recipe.exposure = 2.9; recipe.grain = 7.9; recipe.warmth = 0.3
        var mask = LocalMask(); mask.exposure = 2.9; recipe.masks = [mask]
        for tool in PrintTool.allCases {
            let current = tool.variation(recipe, direction: 0, step: 1, maskID: mask.id)
            XCTAssertEqual(current, recipe)
            let more = tool.variation(recipe, direction: 1, step: 2, maskID: mask.id)
            XCTAssertEqual(more.filmID, recipe.filmID); XCTAssertEqual(more.warmth, recipe.warmth)
            XCTAssertLessThanOrEqual(more.exposure, 3); XCTAssertLessThanOrEqual(more.grain, 8)
            XCTAssertLessThanOrEqual(more.masks[0].exposure, 3)
        }
    }
    @MainActor func testVersionsPersistRestoreAndUndo() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        let photo = Photograph(url: URL(fileURLWithPath: "/test.jpg"), recipe: Recipe())
        library.photos = [photo]; library.selectedID = photo.id
        library.change { $0.exposure = 0.7 }; library.keepVersion()
        let version = try XCTUnwrap(library.selected?.versions.first)
        library.change { $0.exposure = 1.5 }; library.restoreVersion(version.id)
        XCTAssertEqual(library.recipe.exposure, 0.7)
        library.undo(); XCTAssertEqual(library.recipe.exposure, 1.5)
        let records = try JSONDecoder().decode([PhotoRecord].self, from: Data(contentsOf: dir.appendingPathComponent("session.json")))
        XCTAssertEqual(records[0].versions[0].recipe.exposure, 0.7)
        library.deleteVersion(version.id); XCTAssertTrue(library.selected!.versions.isEmpty)
        library.undo(); XCTAssertEqual(library.selected!.versions[0], version)
        let old = try JSONDecoder().decode(PhotoRecord.self, from: Data("{\"path\":\"/old.jpg\",\"recipe\":{}}".utf8))
        XCTAssertTrue(old.versions.isEmpty); XCTAssertEqual(old.recipe.shadowBalance, 0)
    }
    @MainActor func testFavoriteNavigationAndToolPreviewDoNotAlterRecipe() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        let photo = Photograph(url: URL(fileURLWithPath: "/test.jpg"), recipe: Recipe())
        library.photos = [photo]; library.selectedID = photo.id
        library.toggleFavorite("800t"); library.toggleFavorite("velvia50"); library.favoritesOnly = true
        library.stepFilm(1); XCTAssertEqual(library.recipe.filmID, "800t")
        library.stepFilm(1); XCTAssertEqual(library.recipe.filmID, "velvia50")
        library.stepFilm(1); XCTAssertEqual(library.recipe.filmID, "800t")
        let saved = try JSONDecoder().decode([String].self, from: Data(contentsOf: dir.appendingPathComponent("favorites.json")))
        XCTAssertEqual(Set(saved), ["800t", "velvia50"])
        let before = library.recipe
        library.bypassedTool = .texture
        XCTAssertEqual(library.displayedRecipe.grain, 0); XCTAssertEqual(library.recipe, before)
        library.chooseTool(.color); XCTAssertNil(library.bypassedTool); XCTAssertEqual(library.recipe, before)
    }
    @MainActor func testAlignedComparisonPansBothViewsTogether() async throws {
        let view = AlignedComparison.PairView(frame: NSRect(x: 0, y: 0, width: 700, height: 300))
        view.layout()
        let coordinator = AlignedComparison.Coordinator(); coordinator.connect(view)
        let image = NSImage(size: NSSize(width: 1600, height: 1200))
        coordinator.update(view, left: image, right: image, size: image.size)
        view.scrolls[0].contentView.scroll(to: CGPoint(x: 170, y: 140))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(view.scrolls[0].contentView.bounds.origin.x, view.scrolls[1].contentView.bounds.origin.x, accuracy: 1)
        XCTAssertEqual(view.scrolls[0].contentView.bounds.origin.y, view.scrolls[1].contentView.bounds.origin.y, accuracy: 1)
        view.scrolls[1].contentView.scroll(to: CGPoint(x: 270, y: 240))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(view.scrolls[0].contentView.bounds.origin.x, view.scrolls[1].contentView.bounds.origin.x, accuracy: 1)
        XCTAssertEqual(view.scrolls[0].contentView.bounds.origin.y, view.scrolls[1].contentView.bounds.origin.y, accuracy: 1)
    }

}
extension EngineTests {
    func testPhotographicShadowsAndHighlightsRenderBidirectionally() throws {
        var recipe = Recipe(); recipe.grain = 0; recipe.halation = 0
        let base = try bytes(Engine.develop(fixture(), recipe: recipe))
        recipe.shadowBalance = 0.8
        let lifted = try bytes(Engine.develop(fixture(), recipe: recipe))
        recipe.shadowBalance = -0.8
        let lowered = try bytes(Engine.develop(fixture(), recipe: recipe))
        XCTAssertNotEqual(base, lifted); XCTAssertNotEqual(lifted, lowered)
        recipe.shadowBalance = 0; recipe.highlightBalance = -0.8
        XCTAssertNotEqual(base, try bytes(Engine.develop(fixture(), recipe: recipe)))
        XCTAssertEqual(try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe)), recipe)
    }
}
