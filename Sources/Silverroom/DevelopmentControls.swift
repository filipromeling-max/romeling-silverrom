import SwiftUI

struct DevelopmentControls: View {
    @EnvironmentObject var library: Library
    var body: some View {
        DisclosureGroup("Film response & development") {
            VStack(alignment: .leading, spacing: 16) {
                RecipeSlider(title: "Exposure-aware response", key: \.development.response, suffix: "%")
                RecipeSlider(title: "Push / pull", key: \.development.pushPull, range: -2...3, multiplier: 1, format: "%+.1f", suffix: " stops")
                Text("Response changes color and highlight roll-off with exposure. Push adds contrast and grain; pull softens contrast. These are artistic development interpretations.").font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 14)
        }.font(.system(size: 12))
    }
}
struct GrainControls: View {
    @EnvironmentObject var library: Library
    var body: some View {
        VStack(spacing: 16) {
            Picker("Film format", selection: Binding(get: { library.recipe.development.format }, set: { value in library.change { $0.development.format = value } })) {
                Text("35mm").tag("35mm"); Text("120 / Medium format").tag("120"); Text("110 / Small format").tag("110")
            }.disabled(!library.canEdit)
            RecipeSlider(title: "Image-aware grain", key: \.development.adaptiveGrain, suffix: "%")
            RecipeSlider(title: "Grain color", key: \.development.grainColor, suffix: "%")
        }.font(.system(size: 12))
    }
}
struct HalationControls: View {
    @EnvironmentObject var library: Library
    var body: some View {
        DisclosureGroup("Advanced halation") {
            VStack(alignment: .leading, spacing: 16) {
                RecipeSlider(title: "Edge halation", key: \.development.advancedHalation, suffix: "%")
                RecipeSlider(title: "Highlight threshold", key: \.development.halationThreshold, range: 0.1...0.95, suffix: "%")
                RecipeSlider(title: "Halation spread", key: \.development.halationSpread, suffix: "%")
                RecipeSlider(title: "Halation hue", key: \.development.halationHue, multiplier: 360, suffix: "°", hue: true)
                Text("Set Edge halation above zero to replace the stock glow with an edge-aware halo. Halation amount scales its intensity. Works on every stock.").font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 14)
        }.font(.system(size: 12))
    }
}
struct ScannerControls: View {
    @EnvironmentObject var library: Library
    var body: some View {
        DisclosureGroup("04 / Scanner & print") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Interpretation", selection: Binding(get: { library.recipe.development.scanner }, set: { value in library.change { $0.development.scanner = value } })) {
                    Text("Neutral scan").tag("neutral"); Text("Warm minilab").tag("minilab")
                    Text("Cool editorial").tag("editorial"); Text("Soft print").tag("print")
                }.disabled(!library.canEdit)
                RecipeSlider(title: "Scanner strength", key: \.development.scannerStrength, suffix: "%")
                RecipeSlider(title: "Scan contrast", key: \.development.scanContrast, range: 0.7...1.3, suffix: "%")
                RecipeSlider(title: "Scan sharpening", key: \.development.scanSharpness, range: 0...2, suffix: "%")
                Text("Interpret the developed film through a separate scanning stage. These are authored looks, not profiles of specific scanners.").font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 14)
        }.font(.system(size: 12))
    }
}
struct LocalMaskControls: View {
    @EnvironmentObject var library: Library
    var active: LocalMask? { library.recipe.masks.first { $0.id == library.activeMaskID } }
    var body: some View {
        DisclosureGroup("05 / Local development") {
            VStack(alignment: .leading, spacing: 14) {
                Menu {
                    ForEach(MaskKind.allCases, id: \.self) { kind in Button(kind.rawValue) { library.addMask(kind) } }
                } label: { Label("Add mask", systemImage: "plus.circle") }.disabled(!library.canEdit || library.recipe.masks.count >= 16)
                if library.recipe.masks.isEmpty { Text("Add a mask to adjust one part of the photograph.").font(.caption).foregroundStyle(.secondary) }
                ForEach(library.recipe.masks) { mask in
                    HStack {
                        Button { library.editingMask = false; library.activeMaskID = mask.id } label: {
                            Label(mask.name, systemImage: library.activeMaskID == mask.id ? "circle.inset.filled" : "circle").lineLimit(1)
                        }.buttonStyle(.borderless)
                        Spacer()
                        Toggle("Enable mask", isOn: Binding(get: { library.recipe.masks.first { $0.id == mask.id }?.enabled ?? false }, set: { value in library.editMask(mask.id) { $0.enabled = value } }))
                            .labelsHidden().toggleStyle(.checkbox).accessibilityLabel("Enable " + mask.name)
                    }
                }
                if let active {
                    TextField("Mask name", text: Binding(get: { self.active?.name ?? "" }, set: { value in library.editMask(active.id) { $0.name = value } })).textFieldStyle(.roundedBorder)
                    Toggle("Invert selection", isOn: Binding(get: { self.active?.inverted ?? false }, set: { value in library.editMask(active.id) { $0.inverted = value } }))
                    HStack {
                        Button(library.editingMask ? "Done placing" : active.kind == .brush ? "Paint on image" : "Place on image") { library.beginMaskEditing() }
                            .disabled(active.kind == .luminance || active.kind == .color || !library.canEdit)
                        Toggle("Show mask", isOn: $library.showMask).toggleStyle(.checkbox)
                    }
                    if active.kind == .brush {
                        Toggle("Eraser", isOn: $library.erasingMask)
                        Button("Clear brush strokes") { library.editMask(active.id) { $0.strokes = [] } }
                    }
                    if active.kind == .radial || active.kind == .brush || active.kind == .gradient {
                        maskSlider("Size / brush radius", key: \.radius, range: 0.01...1)
                        if active.kind != .gradient { maskSlider("Feather", key: \.feather) }
                        if active.kind != .brush {
                            maskSlider("Horizontal position", key: \.x)
                            maskSlider("Vertical position", key: \.y)
                        }
                    }
                    if active.kind == .gradient { maskSlider("Gradient angle", key: \.angle, range: 0...360, multiplier: 1, suffix: "°") }
                    if active.kind == .luminance { maskSlider("Luminance threshold", key: \.threshold, range: 0...0.95) }
                    if active.kind == .color {
                        maskSlider("Selected hue", key: \.hue, multiplier: 360, suffix: "°")
                        maskSlider("Hue range", key: \.hueWidth, range: 0.02...0.5, multiplier: 360, suffix: "°")
                    }
                    Divider()
                    maskSlider("Local exposure", key: \.exposure, range: -3...3, multiplier: 1, suffix: " EV")
                    maskSlider("Local warmth", key: \.warmth, range: -1...1)
                    maskSlider("Local saturation", key: \.saturation, range: 0...2)
                    maskSlider("Local contrast", key: \.contrast, range: 0.7...1.3)
                    maskSlider("Local softness", key: \.softness)
                    Button("Delete mask", role: .destructive) { library.deleteMask(active.id) }
                    Text("Mask positions are relative to the image. Show mask is a preview overlay and is never exported. Brush strokes support undo; use sliders to position radial and gradient masks precisely.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.top, 14)
        }.font(.system(size: 12))
    }
    private func maskSlider(_ title: String, key: WritableKeyPath<LocalMask, Double>, range: ClosedRange<Double> = 0...1, multiplier: Double = 100, suffix: String = "%") -> some View {
        VStack(spacing: 6) {
            HStack { Text(title); Spacer(); Text(String(format: "%.1f", (active?[keyPath: key] ?? 0) * multiplier) + suffix).foregroundStyle(.secondary).monospacedDigit() }
            Slider(value: Binding(get: { active?[keyPath: key] ?? range.lowerBound }, set: { value in if let id = active?.id { library.editMask(id) { $0[keyPath: key] = value } } }), in: range, onEditingChanged: library.adjustmentGesture)
                .controlSize(.small).accessibilityLabel(title).disabled(!library.canEdit)
        }
    }
}

struct MaskPlacement: View {
    @EnvironmentObject var library: Library
    let size: CGSize
    @State private var points: [MaskPoint] = []
    @State private var dragging = false
    var body: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            if let mask = library.recipe.masks.first(where: { $0.id == library.activeMaskID }), mask.kind != .brush {
                Image(systemName: "scope").font(.title2).foregroundStyle(.white)
                    .position(x: mask.x * size.width, y: mask.y * size.height)
            }
            VStack { Text(library.erasingMask ? "ERASE MASK" : "PLACE OR PAINT MASK").font(.caption).padding(8).background(.black.opacity(0.7)); Spacer() }.allowsHitTesting(false)
            if !points.isEmpty {
                Path { path in
                    for (index, point) in points.enumerated() {
                        let p = CGPoint(x: point.x * size.width, y: point.y * size.height)
                        if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                }.stroke(Color.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round)).allowsHitTesting(false)
            }
        }.frame(width: size.width, height: size.height)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard let id = library.activeMaskID, let mask = library.recipe.masks.first(where: { $0.id == id }) else { return }
                if !dragging { dragging = true; library.adjustmentGesture(true) }
                let point = MaskPoint(x: min(1, max(0, value.location.x / size.width)), y: min(1, max(0, value.location.y / size.height)))
                if mask.kind == .brush {
                    if points.count < 2000 { points.append(point) }
                } else { library.editMask(id) { $0.x = point.x; $0.y = point.y } }
            }.onEnded { _ in
                if let id = library.activeMaskID, !points.isEmpty { let stroke = MaskStroke(points: points, erase: library.erasingMask); library.editMask(id) { $0.strokes.append(stroke) } }
                points = []; dragging = false; library.adjustmentGesture(false)
            }).onDisappear { points = []; if dragging { library.adjustmentGesture(false); dragging = false } }
    }
}
