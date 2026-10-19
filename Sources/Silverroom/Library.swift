import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Photograph: Identifiable {
    var id = UUID()
    var url: URL
    var recipe: Recipe
    var thumbnail: NSImage?
    var versions: [KeptVersion] = []
    var name: String { url.deletingPathExtension().lastPathComponent }
}
enum HistoryAction {
    case adjustment(UUID, Recipe)
    case reopen(Photograph, Int, UUID?)
    case close(UUID)
    case versions(UUID, [KeptVersion])
}
@MainActor final class Library: ObservableObject {
    @Published var activeTool: PrintTool = .light
    @Published var bypassedTool: PrintTool?
    @Published var directAdjustment = false
    @Published var autoLightTarget = true
    @Published var lightRegion: LightRegion = .exposure
    @Published var glowTool: GlowTool = .halation
    @Published var loupePoint = MaskPoint(x: 0.5, y: 0.5)
    @Published var loupeImage: NSImage?
    @Published var loupeVisible = true
    @Published var versionPreview: NSImage?
    @Published var comparisonVersionID: UUID?
    @Published var explorationBase: Recipe?
    @Published var favoriteFilms: Set<String> = []
    @Published var favoritesOnly = false
    @Published var inspectorVisible = true
    @Published var sessionVisible = false
    var workingImage: CIImage? { previewSource }
    var workingImageID: String { (selectedID?.uuidString ?? "") + String(busy) }
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
    @Published var comparisonMode: ComparisonMode = .developed
    @Published var splitPosition = 0.5
    @Published var zoomLevel = 0.0
    var compare: Bool {
        get { comparisonMode != .developed }
        set { comparisonMode = newValue ? .vertical : .developed }
    }
    var zoom: Bool {
        get { zoomLevel != 0 }
        set { zoomLevel = newValue ? 1 : 0 }
    }
    static let zoomSteps: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4]
    static var orderedFilms: [Film] { Film.all.sorted { ($0.maker, $0.name) < ($1.maker, $1.name) } }
    func stepZoom(_ direction: Int) {
        if zoomLevel == 0 { zoomLevel = direction > 0 ? 1 : 0.5; return }
        let index = Self.zoomSteps.firstIndex(of: zoomLevel) ?? 3
        zoomLevel = Self.zoomSteps[min(Self.zoomSteps.count - 1, max(0, index + direction))]
    }
    func stepFilm(_ direction: Int) {
        let films = filmChoices
        guard let index = films.firstIndex(where: { $0.id == recipe.filmID }) else {
            if let film = direction > 0 ? films.first : films.last { change { $0.filmID = film.id } }
            return
        }
        let next = (index + direction % films.count + films.count) % films.count
        adjustmentGesture(false)
        change { $0.filmID = films[next].id }
    }
    func toggleOriginal() { comparisonVersionID = nil; versionPreview = nil; comparisonMode = comparisonMode == .original ? .developed : .original }
    @Published var activeMaskID: UUID?
    @Published var editingMask = false
    @Published var showMask = false
    @Published var erasingMask = false
    @Published var maskPreview: NSImage?
    func addMask(_ kind: MaskKind) {
        guard recipe.masks.count < 16 else { return }
        var mask = LocalMask(); mask.kind = kind; if kind == .brush { mask.radius = 0.08 }; mask.name = kind.rawValue + " " + String(recipe.masks.count + 1)
        change { $0.masks.append(mask) }; activeMaskID = mask.id; showMask = true
        if kind == .radial || kind == .gradient || kind == .brush { editingMask = true; placingLight = false; compare = false; zoom = false }
    }
    func editMask(_ id: UUID, _ edit: (inout LocalMask) -> Void) {
        change { recipe in guard let index = recipe.masks.firstIndex(where: { $0.id == id }) else { return }; edit(&recipe.masks[index]) }
    }
    func deleteMask(_ id: UUID) {
        change { $0.masks.removeAll { $0.id == id } }
        activeMaskID = recipe.masks.first?.id; editingMask = false
    }
    func beginMaskEditing() {
        editingMask.toggle()
        if editingMask { placingLight = false; compare = false; zoom = false; showMask = true }
    }
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
            if let data = try? Data(contentsOf: directory.appendingPathComponent("favorites.json")), let ids = try? JSONDecoder().decode([String].self, from: data) { favoriteFilms = Set(ids) }
            if let data = try? Data(contentsOf: directory.appendingPathComponent("recipes.json")), let saved = try? JSONDecoder().decode([SavedRecipe].self, from: data) { recipes = saved }
            if let data = try? Data(contentsOf: directory.appendingPathComponent("session.json")), let records = try? JSONDecoder().decode([PhotoRecord].self, from: data) {
                photos = records.map { Photograph(url: URL(fileURLWithPath: $0.path), recipe: $0.recipe, versions: $0.versions) }
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
        placingLight = false; editingMask = false; activeMaskID = nil; maskPreview = nil; showMask = false; adjustmentGesture(false)
        bypassedTool = nil; directAdjustment = false; explorationBase = nil; comparisonVersionID = nil; versionPreview = nil; loupeImage = nil
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
        bypassedTool = nil
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
        bypassedTool = nil
        adjustmentGesture(false)
        guard let action = undoStack.popLast(), let inverse = apply(action) else { return }
        redoStack.append(inverse)
    }
    func redo() {
        bypassedTool = nil
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
        case let .versions(id, versions):
            guard let index = photos.firstIndex(where: { $0.id == id }) else { return nil }
            let inverse = HistoryAction.versions(id, photos[index].versions)
            photos[index].versions = versions
            if selectedID == id, !versions.contains(where: { $0.id == comparisonVersionID }) { comparisonVersionID = nil; versionPreview = nil }
            persist(); render(); return inverse
        }
    }
    func render() {
        guard let input = zoom ? source : previewSource else { return }
        generation += 1
        let token = generation, recipe = displayedRecipe, width = size.width
        let versionRecipe = selected?.versions.first { $0.id == comparisonVersionID }?.recipe
        let fullSource = source, point = loupePoint
        let needsLoupe = activeTool == .texture && loupeVisible
        let activeMask = showMask ? recipe.masks.first { $0.id == activeMaskID } : nil
        renderTask?.cancel()
        status = "Developing…"
        let work = DispatchWorkItem { [weak self] in
            do {
                let cg = try Engine.cgImage(Engine.develop(input, recipe: recipe, originalWidth: width))
                let originalCG = try Engine.cgImage(input)
                let versionCG = try versionRecipe.map { try Engine.cgImage(Engine.develop(input, recipe: $0, originalWidth: width)) }
                var loupeCG: CGImage?
                if needsLoupe, let fullSource {
                    let e = fullSource.extent, side = min(256, min(e.width, e.height))
                    let rect = CGRect(x: max(0, min(e.width - side, point.x * e.width - side / 2)), y: max(0, min(e.height - side, (1 - point.y) * e.height - side / 2)), width: side, height: side).integral
                    loupeCG = try Engine.cgImage(Engine.develop(fullSource, recipe: recipe).cropped(to: rect))
                }
                let maskCG: CGImage?
                if let activeMask {
                    var unmasked = recipe; unmasked.masks = []
                    let base = Engine.develop(input, recipe: unmasked, originalWidth: width)
                    maskCG = try Engine.cgImage(Engine.localMask(activeMask, image: base))
                } else { maskCG = nil }
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.versionPreview = versionCG.map { NSImage(cgImage: $0, size: .zero) }; self.loupeImage = loupeCG.map { NSImage(cgImage: $0, size: .zero) }; self.maskPreview = maskCG.map { NSImage(cgImage: $0, size: .zero) }; self.preview = NSImage(cgImage: cg, size: .zero); self.original = NSImage(cgImage: originalCG, size: .zero); self.status = "All adjustments saved"
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
    func toggleFavorite(_ id: String) {
        if favoriteFilms.contains(id) { favoriteFilms.remove(id) } else { favoriteFilms.insert(id) }
        do { try JSONEncoder().encode(favoriteFilms.sorted()).write(to: directory.appendingPathComponent("favorites.json"), options: .atomic) }
        catch { self.error = "Could not save favorite films: \(error.localizedDescription)" }
    }
    func keepVersion() {
        guard let index = photos.firstIndex(where: { $0.id == selectedID }) else { return }
        undoStack.append(.versions(photos[index].id, photos[index].versions)); redoStack.removeAll()
        let number = (photos[index].versions.compactMap { Int($0.name.split(separator: " ").dropFirst().first ?? "") }.max() ?? 0) + 1
        photos[index].versions.append(KeptVersion(name: "Version \(number) · \(recipe.film.name)", recipe: recipe))
        persist(); status = "Version kept"
    }
    func deleteVersion(_ id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == selectedID }) else { return }
        undoStack.append(.versions(photos[index].id, photos[index].versions)); redoStack.removeAll()
        photos[index].versions.removeAll { $0.id == id }
        if comparisonVersionID == id { comparisonVersionID = nil; versionPreview = nil }
        persist(); render()
    }
    func restoreVersion(_ id: UUID) {
        guard let version = selected?.versions.first(where: { $0.id == id }) else { return }
        adjustmentGesture(false); change { $0 = version.recipe }
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
                size = .zero; busy = false; compare = false; zoom = false; placingLight = false; editingMask = false; maskPreview = nil; activeMaskID = nil; showMask = false; versionPreview = nil; comparisonVersionID = nil; loupeImage = nil; bypassedTool = nil; directAdjustment = false; explorationBase = nil
                status = "Ready for your next frame"
            }
        }
        return inverse
    }
    func export(format: String) {
        guard bypassedTool == nil, let image = source, let selected else { return }
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
            let records = photos.map { PhotoRecord(path: $0.url.path, recipe: $0.recipe, versions: $0.versions) }
            try JSONEncoder().encode(records).write(to: directory.appendingPathComponent("session.json"), options: .atomic)
            try JSONEncoder().encode(recipes).write(to: directory.appendingPathComponent("recipes.json"), options: .atomic)
        } catch { self.error = "Your adjustments could not be saved: \(error.localizedDescription)" }
    }
}
