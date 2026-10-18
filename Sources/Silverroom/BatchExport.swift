import AppKit
import SwiftUI

struct BatchItem {
    let source: URL
    let recipe: Recipe
}
struct BatchResult: Identifiable {
    let id = UUID()
    let name: String
    let output: URL?
    let failure: String?
}
@MainActor final class BatchExporter: ObservableObject {
    @Published var running = false
    @Published var stopping = false
    @Published var total = 0
    @Published var currentName = ""
    @Published var results: [BatchResult] = []
    @Published var folder: URL?
    @Published var error: String?
    private var task: Task<Void, Never>?

    static func items(from photos: [Photograph], ids: Set<UUID>, sharedRecipe: Recipe?) -> [BatchItem] {
        photos.filter { ids.contains($0.id) }.map { BatchItem(source: $0.url, recipe: sharedRecipe ?? $0.recipe) }
    }
    func start(items: [BatchItem], destination: URL, format: String) {
        guard !running, !items.isEmpty, ["jpg", "png", "tiff"].contains(format) else { return }
        error = nil; folder = nil; results = []; total = items.count; stopping = false
        // A new directory per run keeps existing exports and originals untouched.
        let output = destination.appendingPathComponent("Silverroom-" + UUID().uuidString, isDirectory: true)
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false) }
        catch { self.error = error.localizedDescription; return }
        folder = output; running = true
        task = Task {
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                currentName = item.source.lastPathComponent
                let url = output.appendingPathComponent(String(format: "%04d-", index + 1) + item.source.deletingPathExtension().lastPathComponent + "-developed." + format)
                let result = await Task.detached(priority: .userInitiated) {
                    autoreleasepool { () -> BatchResult in
                        do {
                            let image = try Engine.load(item.source)
                            try Engine.export(Engine.develop(image, recipe: item.recipe), to: url, format: format)
                            return BatchResult(name: item.source.lastPathComponent, output: url, failure: nil)
                        } catch {
                            try? FileManager.default.removeItem(at: url)
                            return BatchResult(name: item.source.lastPathComponent, output: nil, failure: error.localizedDescription)
                        }
                    }
                }.value
                results.append(result)
            }
            currentName = ""; running = false; task = nil
        }
    }
    func cancel() { stopping = true; task?.cancel() }
}

struct BatchExportView: View {
    @EnvironmentObject var library: Library
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exporter = BatchExporter()
    @State private var selected: Set<UUID> = []
    @State private var useCurrentRecipe = true
    @State private var format = "jpg"
    @State private var destination: URL?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Batch develop").font(.title2); Spacer(); Text("\(selected.count) images").foregroundStyle(.secondary) }
            if exporter.folder == nil {
                Text("Choose photographs, a look, and an export folder.").foregroundStyle(.secondary)
                HStack {
                    Button("Select all") { selected = Set(library.photos.map(\.id)) }
                    Button("Deselect all") { selected.removeAll() }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(library.photos) { photo in
                            Toggle(isOn: Binding(get: { selected.contains(photo.id) }, set: { if $0 { selected.insert(photo.id) } else { selected.remove(photo.id) } })) {
                                HStack { Text(photo.url.lastPathComponent).lineLimit(1); Spacer(); Text(photo.recipe.film.name).foregroundStyle(.secondary).font(.caption) }
                            }
                        }
                    }.padding(4)
                }.frame(height: 160)
                Picker("Develop with", selection: $useCurrentRecipe) {
                    Text("Current image’s film & adjustments").tag(true)
                    Text("Each image’s own settings").tag(false)
                }
                Text(useCurrentRecipe ? "Uses \(library.recipe.film.name) and all current adjustments for every export. Session settings stay unchanged." : "Uses the settings saved for each selected image.").font(.caption).foregroundStyle(.secondary)
                Picker("Format", selection: $format) {
                    Text("JPEG · 95%").tag("jpg"); Text("PNG · Lossless").tag("png"); Text("TIFF · 16-bit").tag("tiff")
                }
                HStack {
                    Button("Choose folder…") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                        panel.canCreateDirectories = true; panel.prompt = "Choose"
                        if panel.runModal() == .OK { destination = panel.url }
                    }
                    Text(destination?.path ?? "No folder selected").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Text("Exports go into a new subfolder. Original files are never overwritten.").font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView(value: Double(exporter.results.count), total: Double(exporter.total))
                Text(exporter.running ? "\(exporter.results.count) of \(exporter.total) completed · \(exporter.currentName)" : "\(exporter.results.filter { $0.output != nil }.count) exported · \(exporter.results.filter { $0.failure != nil }.count) failed · \(exporter.total - exporter.results.count) not processed")
                    .font(.callout)
                if exporter.stopping { Text(exporter.running ? "Stopping after the current image…" : "Batch stopped. Completed exports are kept.").foregroundStyle(.secondary) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(exporter.results) { result in
                            Label { Text(result.name + (result.failure.map { " — " + $0 } ?? "")) }
                            icon: { Image(systemName: result.failure == nil ? "checkmark.circle" : "exclamationmark.triangle") }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 230)
            }
            if let error = exporter.error { Text(error).foregroundStyle(.red) }
            HStack {
                if exporter.running { Button(exporter.stopping ? "Stopping…" : "Stop batch", action: exporter.cancel).disabled(exporter.stopping) }
                else { Button(exporter.folder == nil ? "Cancel" : "Done") { dismiss() }.keyboardShortcut(.cancelAction) }
                Spacer()
                if let folder = exporter.folder {
                    Button("Show exports") { NSWorkspace.shared.open(folder) }
                } else {
                    Button("Export \(selected.count) images") {
                        guard let destination else { return }
                        exporter.start(items: BatchExporter.items(from: library.photos, ids: selected, sharedRecipe: useCurrentRecipe ? library.recipe : nil), destination: destination, format: format)
                    }.buttonStyle(.borderedProminent).disabled(selected.isEmpty || destination == nil || library.exporting).keyboardShortcut(.defaultAction)
                }
            }
        }.padding(28).frame(width: 560).interactiveDismissDisabled(exporter.running)
        .onAppear { selected = Set(library.photos.map(\.id)) }
    }
}
