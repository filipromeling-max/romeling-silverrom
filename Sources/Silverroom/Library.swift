import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Photograph: Identifiable {
    var id = UUID()
    var url: URL
    var recipe: Recipe
    var thumbnail: NSImage?
    var name: String { url.deletingPathExtension().lastPathComponent }
}
enum HistoryAction {
    case adjustment(UUID, Recipe)
    case reopen(Photograph, Int, UUID?)
    case close(UUID)
}
@MainActor final class Library: ObservableObject {
    @Published var photos: [Photograph] = []
    @Published var selectedID: UUID?
    @Published var preview: NSImage?
    @Published var original: NSImage?
    @Published var size = CGSize.zero
    @Published var busy = false
    @Published var exporting = false
    @Published var status = "Ready for your next frame"
    @Published var error: String?
    @Published var recipes: [SavedRecipe] = []
    @Published var compare = false
    @Published var zoom = false
    @Published var placingLight = false
    @Published var undoStack: [HistoryAction] = []
    @Published var redoStack: [HistoryAction] = []
    private var source: CIImage?
    private var previewSource: CIImage?
    private var generation = 0
    private var groupingAdjustment = false
    private var recordedAdjustment = false
    private var renderTask: DispatchWorkItem?
    private let queue = DispatchQueue(label: "studio.silverroom.processing", qos: .userInitiated)
    private let directory: URL
    var selected: Photograph? { photos.first { $0.id == selectedID } }
    var recipe: Recipe { selected?.recipe ?? Recipe() }
    var canEdit: Bool { source != nil && !busy }
    init(restore: Bool = true, storageDirectory: URL? = nil) {
        directory = storageDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Silverroom")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if restore {
            if let data = try? Data(contentsOf: directory.appendingPathComponent("recipes.json")), let saved = try? JSONDecoder().decode([SavedRecipe].self, from: data) { recipes = saved }
            if let data = try? Data(contentsOf: directory.appendingPathComponent("session.json")), let records = try? JSONDecoder().decode([PhotoRecord].self, from: data) {
                photos = records.map { Photograph(url: URL(fileURLWithPath: $0.path), recipe: $0.recipe) }
                if let first = photos.first { select(first.id) }
            }
        }
    }
    func open() {
        let panel = NSOpenPanel()
        panel.title = "Import photographs"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .rawImage]
        if panel.runModal() == .OK { add(panel.urls) }
    }
    func add(_ urls: [URL]) {
        let files = urls.filter { !$0.hasDirectoryPath }
        guard !files.isEmpty else { return }
        var firstID: UUID?
        for url in files {
            if let existing = photos.first(where: { $0.url == url }) { firstID = firstID ?? existing.id; continue }
            let item = Photograph(url: url, recipe: Recipe())
            photos.append(item)
            firstID = firstID ?? item.id
        }
        persist()
        if let firstID { select(firstID) }
        // Thumbnails are decoded serially and released between files.
        for item in photos where item.thumbnail == nil && item.id != firstID {
            queue.async { [weak self] in
                let cg: CGImage? = autoreleasepool { try? Engine.cgImage(Engine.scaled(Engine.load(item.url), maxDimension: 180)) }
                DispatchQueue.main.async { [weak self] in
                    guard let self, let index = self.photos.firstIndex(where: { $0.id == item.id }), let cg else { return }
                    self.photos[index].thumbnail = NSImage(cgImage: cg, size: .zero)
                }
            }
        }
    }
    func select(_ id: UUID) {
        guard let item = photos.first(where: { $0.id == id }) else { return }
        generation += 1
        let token = generation
        renderTask?.cancel()
        placingLight = false; adjustmentGesture(false)
        selectedID = id; source = nil; previewSource = nil; preview = nil; original = nil
        size = .zero; busy = true; zoom = false; status = "Opening \(item.url.lastPathComponent)…"
        queue.async { [weak self] in
            do {
                let image = try Engine.load(item.url)
                let small = Engine.scaled(image, maxDimension: 1800)
                let cg = try Engine.cgImage(small)
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.source = image; self.previewSource = small; self.size = image.extent.size
                    self.original = NSImage(cgImage: cg, size: .zero)
                    if let index = self.photos.firstIndex(where: { $0.id == id }) { self.photos[index].thumbnail = self.original }
                    self.busy = false; self.render()
                }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.busy = false; self.status = "Could not open photograph"; self.error = message
                }
            }
        }
    }
    func change(_ edit: (inout Recipe) -> Void) {
        guard let index = photos.firstIndex(where: { $0.id == selectedID }) else { return }
        let old = photos[index].recipe
        var new = old; edit(&new)
        guard new != old else { return }
        if !groupingAdjustment || !recordedAdjustment { undoStack.append(.adjustment(photos[index].id, old)); recordedAdjustment = true }; redoStack.removeAll()
        if undoStack.count > 250 { undoStack.removeFirst() }
        photos[index].recipe = new
        persist(); render()
    }
    func adjustmentGesture(_ active: Bool) { groupingAdjustment = active; recordedAdjustment = false }
    func undo() {
        adjustmentGesture(false)
        guard let action = undoStack.popLast(), let inverse = apply(action) else { return }
        redoStack.append(inverse)
    }
    func redo() {
        adjustmentGesture(false)
        guard let action = redoStack.popLast(), let inverse = apply(action) else { return }
        undoStack.append(inverse)
    }
    private func apply(_ action: HistoryAction) -> HistoryAction? {
        switch action {
        case let .adjustment(id, value):
            guard let index = photos.firstIndex(where: { $0.id == id }) else { return nil }
            let inverse = HistoryAction.adjustment(id, photos[index].recipe)
            photos[index].recipe = value
            persist(); if selectedID == id { render() } else { select(id) }
            return inverse
        case let .reopen(photo, index, selection):
            photos.insert(photo, at: min(index, photos.count))
            persist()
            if let selection, selection != selectedID { select(selection) }
            else if selectedID == nil { select(photo.id) }
            return .close(photo.id)
        case let .close(id):
            return closePhoto(id)
        }
    }
    func render() {
        guard let input = zoom ? source : previewSource else { return }
        generation += 1
        let token = generation, recipe = recipe, width = size.width
        renderTask?.cancel()
        status = "Developing…"
        let work = DispatchWorkItem { [weak self] in
            do {
                let cg = try Engine.cgImage(Engine.develop(input, recipe: recipe, originalWidth: width))
                let originalCG = try Engine.cgImage(input)
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.preview = NSImage(cgImage: cg, size: .zero); self.original = NSImage(cgImage: originalCG, size: .zero); self.status = "All adjustments saved"
                }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async { guard let self, self.generation == token else { return }; self.error = message; self.status = "Preview failed" }
            }
        }
        renderTask = work
        queue.asyncAfter(deadline: .now() + 0.075, execute: work)
    }
    func reset(keepingFilm: Bool = false) {
        adjustmentGesture(false)
        let filmID = recipe.filmID
        change { $0 = Recipe(); if keepingFilm { $0.filmID = filmID } }
    }
    func saveRecipe(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        recipes.append(SavedRecipe(name: name, recipe: recipe)); persist()
    }
    func removeSelected() {
        if let id = selectedID { close(id) }
    }
    func close(_ id: UUID) {
        adjustmentGesture(false)
        guard let inverse = closePhoto(id) else { return }
        undoStack.append(inverse); redoStack.removeAll()
        if undoStack.count > 250 { undoStack.removeFirst() }
    }
    private func closePhoto(_ id: UUID) -> HistoryAction? {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return nil }
        let inverse = HistoryAction.reopen(photos[index], index, selectedID)
        photos.remove(at: index); persist()
        if selectedID == id {
            if !photos.isEmpty { select(photos[min(index, photos.count - 1)].id) }
            else {
                generation += 1; renderTask?.cancel()
                selectedID = nil; preview = nil; original = nil; source = nil; previewSource = nil
                size = .zero; busy = false; compare = false; zoom = false; placingLight = false
                status = "Ready for your next frame"
            }
        }
        return inverse
    }
    func export(format: String) {
        guard let image = source, let selected else { return }
        let panel = NSSavePanel()
        panel.title = "Export developed photograph"
        panel.allowedContentTypes = [format == "tiff" ? .tiff : format == "png" ? .png : .jpeg]
        panel.nameFieldStringValue = selected.name + "-" + recipe.film.name.replacingOccurrences(of: " ", with: "-") + "." + format
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !photos.contains(where: { $0.url.resolvingSymlinksInPath().standardizedFileURL == url.resolvingSymlinksInPath().standardizedFileURL }) else { error = "Choose a different filename to preserve your original photograph."; return }
        let recipe = recipe
        exporting = true; status = "Exporting full resolution…"
        queue.async { [weak self] in
            do {
                try Engine.export(Engine.develop(image, recipe: recipe), to: url, format: format)
                DispatchQueue.main.async { self?.exporting = false; self?.status = "Exported \(url.lastPathComponent)"; NSWorkspace.shared.activateFileViewerSelecting([url]) }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async { self?.exporting = false; self?.error = message; self?.status = "Export failed" }
            }
        }
    }
    private func persist() {
        do {
            let records = photos.map { PhotoRecord(path: $0.url.path, recipe: $0.recipe) }
            try JSONEncoder().encode(records).write(to: directory.appendingPathComponent("session.json"), options: .atomic)
            try JSONEncoder().encode(recipes).write(to: directory.appendingPathComponent("recipes.json"), options: .atomic)
        } catch { self.error = "Your adjustments could not be saved: \(error.localizedDescription)" }
    }
}
