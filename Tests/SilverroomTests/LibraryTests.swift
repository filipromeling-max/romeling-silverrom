import XCTest
@testable import Silverroom

final class LibraryTests: XCTestCase {
    @MainActor func testGestureUndoRedoAndIndependentPhotoRecipes() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        let first = Photograph(url: URL(fileURLWithPath: "/first.jpg"), recipe: Recipe())
        let second = Photograph(url: URL(fileURLWithPath: "/second.jpg"), recipe: Recipe())
        library.photos = [first, second]; library.selectedID = first.id
        library.adjustmentGesture(true)
        library.change { $0.exposure = 0.5 }
        library.change { $0.exposure = 1.5 }
        library.adjustmentGesture(false)
        XCTAssertEqual(library.undoStack.count, 1)
        library.undo(); XCTAssertEqual(library.recipe.exposure, 0)
        library.redo(); XCTAssertEqual(library.recipe.exposure, 1.5)
        XCTAssertEqual(library.photos[1].recipe.exposure, 0)
        library.saveRecipe(name: "Test recipe")
        let records = try JSONDecoder().decode([PhotoRecord].self, from: Data(contentsOf: dir.appendingPathComponent("session.json")))
        XCTAssertEqual(records[0].recipe.exposure, 1.5)
        XCTAssertEqual(records[1].recipe.exposure, 0)
        let recipes = try JSONDecoder().decode([SavedRecipe].self, from: Data(contentsOf: dir.appendingPathComponent("recipes.json")))
        XCTAssertEqual(recipes.first?.recipe.exposure, 1.5)
        library.undo(); library.change { $0.exposure = 0.8 }
        XCTAssertTrue(library.redoStack.isEmpty)
    }
    @MainActor func testCloseUnselectedAndUndoPreserveOrderAndSettings() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        let first = Photograph(url: URL(fileURLWithPath: "/first.jpg"), recipe: Recipe())
        var second = Photograph(url: URL(fileURLWithPath: "/second.jpg"), recipe: Recipe())
        second.recipe.exposure = 1.25
        library.photos = [first, second]; library.selectedID = first.id
        library.close(second.id)
        XCTAssertEqual(library.photos.map(\.id), [first.id])
        XCTAssertEqual(library.selectedID, first.id)
        library.undo()
        XCTAssertEqual(library.photos.map(\.id), [first.id, second.id])
        XCTAssertEqual(library.photos[1].recipe.exposure, 1.25)
        XCTAssertEqual(library.selectedID, first.id)
        library.redo()
        XCTAssertEqual(library.photos.count, 1)
        let records = try JSONDecoder().decode([PhotoRecord].self, from: Data(contentsOf: dir.appendingPathComponent("session.json")))
        XCTAssertEqual(records.map(\.path), [first.url.path])
    }
    @MainActor func testClosingLastImageClearsSessionAndInvalidatesPendingLoad() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        let photo = Photograph(url: dir.appendingPathComponent("missing.jpg"), recipe: Recipe())
        library.photos = [photo]; library.select(photo.id)
        library.compare = true; library.zoom = true; library.placingLight = true
        library.removeSelected()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(library.photos.isEmpty)
        XCTAssertNil(library.selectedID); XCTAssertNil(library.preview); XCTAssertNil(library.original)
        XCTAssertFalse(library.busy); XCTAssertFalse(library.compare); XCTAssertFalse(library.zoom)
        XCTAssertFalse(library.placingLight); XCTAssertNil(library.error)
        let records = try JSONDecoder().decode([PhotoRecord].self, from: Data(contentsOf: dir.appendingPathComponent("session.json")))
        XCTAssertTrue(records.isEmpty)
    }
    @MainActor func testResetChoicesAndUndo() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        var edited = Recipe()
        edited.filmID = "800t"; edited.exposure = 1.2; edited.lightLeak = 0.7; edited.fade = 0.4
        let photo = Photograph(url: URL(fileURLWithPath: "/first.jpg"), recipe: edited)
        library.photos = [photo]; library.selectedID = photo.id
        library.reset(keepingFilm: true)
        var expected = Recipe(); expected.filmID = "800t"
        XCTAssertEqual(library.recipe, expected)
        library.undo(); XCTAssertEqual(library.recipe, edited)
        library.reset(); XCTAssertEqual(library.recipe, Recipe())
        library.undo(); XCTAssertEqual(library.recipe, edited)
        library.redo(); XCTAssertEqual(library.recipe, Recipe())
    }

    @MainActor func testFilmNavigationWrapsAndPreservesAdjustments() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        var recipe = Recipe(); recipe.filmID = Library.orderedFilms[0].id; recipe.grain = 6; recipe.exposure = 1
        let photo = Photograph(url: URL(fileURLWithPath: "/test.jpg"), recipe: recipe)
        library.photos = [photo]; library.selectedID = photo.id
        library.stepFilm(-1)
        XCTAssertEqual(library.recipe.filmID, Library.orderedFilms.last?.id)
        XCTAssertEqual(library.recipe.grain, 6); XCTAssertEqual(library.recipe.exposure, 1)
        library.stepFilm(1); XCTAssertEqual(library.recipe, recipe)
        library.undo(); XCTAssertEqual(library.recipe.filmID, Library.orderedFilms.last?.id)
    }
    @MainActor func testZoomBoundsAndComparisonModes() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        library.stepZoom(1); XCTAssertEqual(library.zoomLevel, 1)
        for _ in 0..<20 { library.stepZoom(1) }
        XCTAssertEqual(library.zoomLevel, 4)
        for _ in 0..<20 { library.stepZoom(-1) }
        XCTAssertEqual(library.zoomLevel, 0.25)
        library.zoom = false; XCTAssertEqual(library.zoomLevel, 0)
        library.comparisonMode = .sideBySide; XCTAssertTrue(library.compare)
        library.toggleOriginal(); XCTAssertEqual(library.comparisonMode, .original)
        library.toggleOriginal(); XCTAssertEqual(library.comparisonMode, .developed)
    }

    @MainActor func testLocalMaskPaintingUndoAndSessionPersistence() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = Library(restore: false, storageDirectory: dir)
        let photo = Photograph(url: URL(fileURLWithPath: "/test.jpg"), recipe: Recipe())
        library.photos = [photo]; library.selectedID = photo.id
        library.addMask(.brush)
        let id = try XCTUnwrap(library.activeMaskID)
        library.adjustmentGesture(true)
        library.editMask(id) { $0.strokes.append(MaskStroke(points: [MaskPoint(x: 0.2, y: 0.3), MaskPoint(x: 0.7, y: 0.4)])) }
        library.adjustmentGesture(false)
        XCTAssertEqual(library.recipe.masks[0].strokes.count, 1)
        library.undo(); XCTAssertTrue(library.recipe.masks[0].strokes.isEmpty)
        library.redo(); XCTAssertEqual(library.recipe.masks[0].strokes.count, 1)
        let records = try JSONDecoder().decode([PhotoRecord].self, from: Data(contentsOf: dir.appendingPathComponent("session.json")))
        XCTAssertEqual(records[0].recipe.masks, library.recipe.masks)
        library.deleteMask(id); XCTAssertTrue(library.recipe.masks.isEmpty)
        library.undo(); XCTAssertEqual(library.recipe.masks[0].strokes.count, 1)
    }

}
