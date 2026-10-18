import AppKit
import SwiftUI

/// A bounded, global statistical match; no geometry or subject transfer.
struct ReferenceMatcher {
    static let parameters: [(WritableKeyPath<Recipe, Double>, ClosedRange<Double>, Double)] = [
        (\.exposure, -3...3, 0.6), (\.warmth, -1...1, 0.3), (\.tint, -1...1, 0.25),
        (\.contrast, 0.7...1.3, 0.12), (\.saturation, 0...2, 0.35),
        (\.shadows, 0...1, 0.25), (\.highlights, 0...1, 0.25)
    ]
    static func signature(_ image: CIImage) throws -> [Double] {
        let image = Engine.scaled(image, maxDimension: 128)
        let cg = try Engine.cgImage(image)
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: Engine.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.message("Could not analyze the photograph.") }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var red = 0.0, green = 0.0, blue = 0.0, saturation = 0.0
        var luminance: [Double] = []
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 127 {
            let alpha = Double(pixels[i + 3])
            let r = Double(pixels[i]) / alpha, g = Double(pixels[i + 1]) / alpha, b = Double(pixels[i + 2]) / alpha
            red += r; green += g; blue += b
            let high = max(r, g, b), low = min(r, g, b)
            saturation += high > 0.001 ? (high - low) / high : 0
            luminance.append(r * 0.2126 + g * 0.7152 + b * 0.0722)
        }
        guard !luminance.isEmpty else { throw Failure.message("The reference has no visible pixels to analyze.") }
        luminance.sort()
        let n = Double(luminance.count)
        return [red/n, green/n, blue/n, saturation/n] + [0.1, 0.25, 0.5, 0.75, 0.9].map { luminance[Int(Double(luminance.count - 1) * $0)] }
    }
    static func distance(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).enumerated().reduce(0) { $0 + pow($1.element.0 - $1.element.1, 2) * ($1.offset < 3 ? 2 : 1) }
    }
    static func suggest(source: CIImage, reference: CIImage, base: Recipe) throws -> Recipe {
        let small = Engine.scaled(source, maxDimension: 256)
        let target = try signature(reference)
        func score(_ recipe: Recipe) throws -> Double {
            try autoreleasepool { try distance(signature(Engine.develop(small, recipe: recipe, originalWidth: source.extent.width)), target) }
        }
        var best = base, bestScore = try score(base)
        for scale in [1.0, 0.5, 0.25] {
            for (key, bounds, step) in parameters {
                let center = best[keyPath: key]
                for direction in [-1.0, 1.0] {
                    var candidate = best
                    candidate[keyPath: key] = min(bounds.upperBound, max(bounds.lowerBound, center + step * scale * direction))
                    let value = try score(candidate)
                    if value < bestScore { best = candidate; bestScore = value }
                }
            }
        }
        return best
    }
    static func blend(base: Recipe, suggestion: Recipe, strength: Double) -> Recipe {
        var result = base
        let strength = min(1, max(0, strength))
        for (key, _, _) in parameters { result[keyPath: key] = base[keyPath: key] + (suggestion[keyPath: key] - base[keyPath: key]) * strength }
        return result
    }
}

@MainActor final class ReferenceMatchModel: ObservableObject {
    @Published var reference: NSImage?
    @Published var before: NSImage?
    @Published var after: NSImage?
    @Published var name = ""
    @Published var busy = false
    @Published var error: String?
    @Published var suggestion: Recipe?
    @Published var strength = 1.0
    private var source: CIImage?
    private var task: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    let photo: Photograph
    init(photo: Photograph) { self.photo = photo }
    var result: Recipe { ReferenceMatcher.blend(base: photo.recipe, suggestion: suggestion ?? photo.recipe, strength: strength) }
    func choose() {
        let panel = NSOpenPanel(); panel.title = "Choose a reference photograph"; panel.allowedContentTypes = [.image, .rawImage]
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }
    func load(_ url: URL) {
        task?.cancel(); previewTask?.cancel(); busy = true; error = nil; suggestion = nil; after = nil; reference = nil; before = nil
        let photo = photo
        task = Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    let source = try Engine.load(photo.url), reference = try Engine.load(url)
                    let suggestion = try ReferenceMatcher.suggest(source: source, reference: reference, base: photo.recipe)
                    let small = Engine.scaled(source, maxDimension: 900)
                    return (small, suggestion, try Engine.cgImage(Engine.scaled(reference, maxDimension: 900)),
                            try Engine.cgImage(Engine.develop(small, recipe: photo.recipe, originalWidth: source.extent.width)), source.extent.width)
                }.value
                guard !Task.isCancelled else { return }
                source = data.0; suggestion = data.1; reference = NSImage(cgImage: data.2, size: .zero)
                before = NSImage(cgImage: data.3, size: .zero); originalWidth = data.4
                name = url.lastPathComponent; strength = 1; busy = false; updatePreview()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription; busy = false
            }
        }
    }
    private var originalWidth: CGFloat = 0
    func updatePreview() {
        previewTask?.cancel()
        guard let source, suggestion != nil else { return }
        let recipe = result, width = originalWidth
        previewTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(90))
                let cg = try await Task.detached(priority: .userInitiated) { try Engine.cgImage(Engine.develop(source, recipe: recipe, originalWidth: width)) }.value
                guard !Task.isCancelled else { return }
                after = NSImage(cgImage: cg, size: .zero)
            } catch is CancellationError {} catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    func cancel() { task?.cancel(); previewTask?.cancel() }
}

struct ReferenceMatchView: View {
    @EnvironmentObject var library: Library
    @Environment(\.dismiss) private var dismiss
    @StateObject var model: ReferenceMatchModel
    @State private var showBefore = false
    init(photo: Photograph) { _model = StateObject(wrappedValue: ReferenceMatchModel(photo: photo)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Match a reference").font(.title2); Spacer(); Button("Choose reference…", action: model.choose).disabled(model.busy) }
            Text("Borrow a photograph’s color and tonal balance. Your film and texture settings stay intact.").foregroundStyle(.secondary)
            HStack(spacing: 16) {
                preview(model.reference, label: model.name.isEmpty ? "REFERENCE" : model.name)
                preview(showBefore ? model.before : model.after, label: showBefore ? "BEFORE MATCH" : "SUGGESTED LOOK")
            }
            if model.busy { ProgressView("Analyzing color and tone…").controlSize(.small) }
            if model.suggestion != nil {
                HStack { Text("Match strength"); Slider(value: $model.strength, in: 0...1).accessibilityLabel("Match strength"); Text("\(Int(model.strength * 100))%").monospacedDigit().frame(width: 42) }
                Toggle("Show before match", isOn: $showBefore)
                Text("Adjusts exposure, warmth, tint, contrast, saturation, shadows and highlights. You can fine-tune them in the inspector after applying.").font(.caption).foregroundStyle(.secondary)
            }
            if let error = model.error { Text(error).foregroundStyle(.red).font(.callout) }
            Text("A global starting point, not an exact copy. Different subjects and lighting affect the result. Matching runs locally; no images are uploaded.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply match") {
                    guard library.selectedID == model.photo.id else { return }
                    library.adjustmentGesture(false)
                    library.change { $0 = model.result }
                    dismiss()
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(model.busy || model.suggestion == nil || model.after == nil || library.selectedID != model.photo.id)
            }
        }.padding(28).frame(width: 730)
            .onChange(of: model.strength) { _, _ in model.updatePreview() }
            .onDisappear { model.cancel() }
    }
    private func preview(_ image: NSImage?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            ZStack {
                Color.black.opacity(0.3)
                if let image { Image(nsImage: image).resizable().scaledToFit() }
                else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
            }.frame(height: 240).frame(maxWidth: .infinity)
        }
    }
}
