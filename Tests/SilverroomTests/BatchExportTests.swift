import XCTest
import CoreImage
@testable import Silverroom

final class BatchExportTests: XCTestCase {
    @MainActor func testSelectionAndRecipeSnapshot() {
        var recipe = Recipe(); recipe.exposure = 1
        let a = Photograph(url: URL(fileURLWithPath: "/a.jpg"), recipe: recipe)
        let b = Photograph(url: URL(fileURLWithPath: "/b.jpg"), recipe: Recipe())
        let individual = BatchExporter.items(from: [a, b], ids: [a.id, b.id], sharedRecipe: nil)
        XCTAssertEqual(individual.map(\.recipe.exposure), [1, 0])
        let shared = BatchExporter.items(from: [a, b], ids: [b.id], sharedRecipe: recipe)
        XCTAssertEqual(shared.count, 1); XCTAssertEqual(shared[0].source, b.url)
        XCTAssertEqual(shared[0].recipe, recipe)
    }
    @MainActor func testBatchContinuesAfterFailureAndAvoidsOverwrite() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("sample.png")
        try Engine.export(CIImage(color: CIColor(red: 0.6, green: 0.4, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 24, height: 24)), to: input, format: "png")
        let original = try Data(contentsOf: input)
        let exporter = BatchExporter()
        let item = BatchItem(source: input, recipe: Recipe())
        exporter.start(items: [item, BatchItem(source: root.appendingPathComponent("missing.raw"), recipe: Recipe()), item], destination: root, format: "png")
        for _ in 0..<500 {
            if !exporter.running { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(exporter.running)
        XCTAssertEqual(exporter.results.count, 3)
        XCTAssertNotNil(exporter.results[1].failure)
        let outputs = exporter.results.compactMap(\.output)
        XCTAssertEqual(Set(outputs).count, 2)
        for output in outputs { XCTAssertEqual(try Engine.load(output).extent.width, 24) }
        XCTAssertEqual(try Data(contentsOf: input), original)
        let previousFolder = exporter.folder
        exporter.start(items: [item], destination: root, format: "png")
        exporter.cancel()
        for _ in 0..<500 {
            if !exporter.running { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(exporter.running); XCTAssertTrue(exporter.stopping)
        XCTAssertNotEqual(exporter.folder, previousFolder)
        XCTAssertTrue(exporter.results.isEmpty)
        XCTAssertTrue(outputs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }
}
