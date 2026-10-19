import SwiftUI

struct LookChoice: Identifiable {
    var id: String
    var title: String
    var recipe: Recipe
    var selected: Bool
}
struct LookPreviews: View {
    @EnvironmentObject var library: Library
    let choices: [LookChoice]
    var choose: (LookChoice) -> Void
    @State private var images: [NSImage] = []
    @State private var message = ""
    private var fingerprint: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return library.workingImageID + ((try? encoder.encode(choices.map(\.recipe)))?.base64EncodedString() ?? "")
    }
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                    Button { choose(choice) } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Color.panel
                                if images.indices.contains(index) { Image(nsImage: images[index]).resizable().scaledToFit() }
                                else { Image(systemName: "photo").foregroundStyle(.secondary) }
                            }.frame(height: 52).frame(maxWidth: .infinity)
                                .overlay(Rectangle().stroke(choice.selected ? Color.accent : Color.clear, lineWidth: 1))
                            Text(choice.title).font(.system(size: 11, weight: choice.selected ? .semibold : .regular)).lineLimit(1)
                                .foregroundStyle(choice.selected ? Color.accent : Color.subtle)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!library.canEdit).accessibilityLabel("Preview " + choice.title)
                }
            }
            if !message.isEmpty { Text(message).font(.system(size: 10)).foregroundStyle(.secondary) }
        }.task(id: fingerprint) {
            images = []
            guard let input = library.workingImage, library.canEdit else { message = "Import a photograph to preview looks"; return }
            message = "Updating previews…"
            let recipes = choices.map(\.recipe), width = library.size.width
            do {
                try await Task.sleep(for: .milliseconds(130))
                let result = try await Task.detached(priority: .utility) {
                    try recipes.map { recipe in
                        try autoreleasepool { try Engine.cgImage(Engine.develop(Engine.scaled(input, maxDimension: 300), recipe: recipe, originalWidth: width)) }
                    }
                }.value
                guard !Task.isCancelled else { return }
                images = result.map { NSImage(cgImage: $0, size: .zero) }; message = ""
            } catch is CancellationError {} catch { if !Task.isCancelled { message = "Could not render these previews" } }
        }
    }
}
struct FilmRibbon: View {
    @EnvironmentObject var library: Library
    @State private var browsing = false
    @State private var step = 1.0
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 14) {
                if library.explorationBase != nil {
                    Text("EXPLORE " + library.activeTool.rawValue.uppercased()).font(.system(size: 10)).tracking(1)
                    Slider(value: $step, in: 0.2...2).frame(maxWidth: 100).accessibilityLabel("Exploration step size")
                    Text("Step " + String(format: "%.1f×", step)).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel exploration") { library.explorationBase = nil }
                } else {
                    Button { browsing = true } label: { Label("Films", systemImage: "square.grid.2x2") }
                        .popover(isPresented: $browsing) { FilmBrowser().environmentObject(library) }
                    Button { library.toggleFavorite(library.recipe.filmID) } label: { Image(systemName: library.favoriteFilms.contains(library.recipe.filmID) ? "star.fill" : "star") }
                        .accessibilityLabel(library.favoriteFilms.contains(library.recipe.filmID) ? "Unfavorite current film" : "Favorite current film")
                    Toggle("Favorites", isOn: $library.favoritesOnly).toggleStyle(.checkbox)
                    Spacer()
                    Button { library.stepFilm(-1) } label: { Image(systemName: "chevron.up") }.accessibilityLabel("Previous film").help("Previous film · ⌥↑")
                    Button { library.stepFilm(1) } label: { Image(systemName: "chevron.down") }.accessibilityLabel("Next film").help("Next film · ⌥↓")
                }
            }.font(.system(size: 11)).buttonStyle(.borderless).disabled(!library.canEdit)
            if library.favoritesOnly && library.favoriteFilms.isEmpty { Text("Star a film to build favorites. Showing all films.").font(.system(size: 10)).foregroundStyle(.secondary) }
            if let base = library.explorationBase {
                let choices = [-1.0, 0, 1].enumerated().map { index, direction in
                    LookChoice(id: String(index), title: ["Less", "Current", "More"][index], recipe: library.activeTool.variation(base, direction: direction, step: step, maskID: library.activeMaskID), selected: direction == 0)
                }
                LookPreviews(choices: choices) { choice in library.adjustmentGesture(false); library.change { $0 = choice.recipe }; library.explorationBase = nil }
            } else {
                let choices = library.ribbonFilms.map { film in
                    var recipe = library.recipe; recipe.filmID = film.id
                    return LookChoice(id: film.id, title: film.name, recipe: recipe, selected: film.id == library.recipe.filmID)
                }
                LookPreviews(choices: choices) { choice in library.adjustmentGesture(false); library.change { $0.filmID = choice.id } }
            }
        }.padding(.horizontal, 28).padding(.vertical, 10).background(Color.room)
    }
}
struct PrintToolBar: View {
    @EnvironmentObject var library: Library
    var body: some View {
        HStack(spacing: 4) {
            ForEach(PrintTool.allCases, id: \.self) { tool in
                Button { library.chooseTool(tool) } label: {
                    Label(tool.rawValue, systemImage: tool.symbol).font(.system(size: 12, weight: library.activeTool == tool ? .semibold : .regular))
                        .padding(.horizontal, 10).frame(minHeight: 32)
                        .background(library.activeTool == tool ? Color.accent.opacity(0.12) : .clear)
                        .foregroundStyle(library.activeTool == tool ? Color.accent : Color.subtle)
                }.buttonStyle(.plain).accessibilityAddTraits(library.activeTool == tool ? .isSelected : [])
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 5).background(Color.panel)
    }
}
struct WorkingInspector: View {
    @EnvironmentObject var library: Library
    var save: () -> Void
    var match: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label(library.activeTool.rawValue, systemImage: library.activeTool.symbol).font(.system(size: 18, weight: .light))
                    Spacer()
                    Button(library.bypassedTool == nil ? "Preview off" : "Return to edit") {
                        library.bypassedTool = library.bypassedTool == nil ? library.activeTool : nil
                        library.editingMask = false; library.placingLight = false; library.directAdjustment = false; library.showMask = false
                    }.font(.system(size: 11)).buttonStyle(.borderless).disabled(!library.canEdit)
                }
                Text(library.activeTool == .local ? (library.activeMaskID.flatMap { id in library.recipe.masks.first { $0.id == id }?.name } ?? "Choose or add a mask") : "WHOLE IMAGE")
                    .font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(Color.accent)
                if library.bypassedTool != nil { Text("Tool is off for preview. Return to edit before exporting.").font(.caption).foregroundStyle(Color.accent) }
                Group {
                    switch library.activeTool {
                    case .light: light
                    case .color: color
                    case .texture: texture
                    case .glow: glow
                    case .local: LocalMaskControls()
                    }
                }
                Divider()
                HStack {
                    Button("Explore") { library.bypassedTool = nil; library.explorationBase = library.recipe }
                        .disabled(!library.canEdit || (library.activeTool == .local && library.activeMaskID == nil))
                    Spacer()
                    Button("Reset " + library.activeTool.rawValue) { library.resetTool() }.disabled(!library.canEdit)
                }.buttonStyle(.borderless).font(.system(size: 11))
                DisclosureGroup("Film & recipes") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(library.recipe.film.maker + " · " + library.recipe.film.name).font(.system(size: 13))
                        RecipeSlider(title: "Film strength", key: \.amount, suffix: "%")
                        Menu("Saved recipes") {
                            if library.recipes.isEmpty { Text("No saved recipes") }
                            ForEach(library.recipes) { saved in Button(saved.name) { library.change { $0 = saved.recipe } } }
                        }.disabled(!library.canEdit)
                        Button("Save current look…", action: save).disabled(!library.canEdit)
                        Menu("Creative starting points") {
                            ForEach(Treatment.allCases, id: \.self) { treatment in Button(treatment.rawValue) { library.change { treatment.apply(to: &$0) } } }
                        }.disabled(!library.canEdit)
                    }.padding(.top, 14)
                }.font(.system(size: 12))
            }.padding(22)
        }.background(Color.panel)
    }
    private var light: some View {
        VStack(alignment: .leading, spacing: 18) {
            RecipeSlider(title: "Exposure", key: \.exposure, range: -3...3, multiplier: 1, format: "%+.2f", suffix: " EV")
            RecipeSlider(title: "Shadows", key: \.shadowBalance, range: -1...1, format: "%+.0f")
            RecipeSlider(title: "Highlights", key: \.highlightBalance, range: -1...1, format: "%+.0f")
            RecipeSlider(title: "Contrast", key: \.contrast, range: 0.7...1.3)
            Button(library.directAdjustment ? "Done adjusting on image" : "Adjust light on image", action: library.startDirectAdjustment).disabled(!library.canEdit)
            Picker("Target", selection: Binding(get: { library.autoLightTarget ? "Auto" : library.lightRegion.rawValue }, set: { value in library.autoLightTarget = value == "Auto"; if let region = LightRegion(rawValue: value) { library.lightRegion = region } })) {
                Text("Pick from image").tag("Auto")
                ForEach(LightRegion.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
            }
            Text("With the image tool active, drag up to brighten or down to darken. Auto picks shadows, midtones or highlights from where you start. This adjusts that tonal region across the whole image.").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Details") {
                VStack(spacing: 16) {
                    DevelopmentControls()
                    RecipeSlider(title: "Highlight recovery", key: \.highlights)
                    RecipeSlider(title: "Shadow recovery", key: \.shadows)
                }.padding(.top, 14)
            }
        }
    }
    private var color: some View {
        VStack(alignment: .leading, spacing: 18) {
            ColorField()
            RecipeSlider(title: "Saturation", key: \.saturation, range: 0...2)
            Button("Match a reference photograph…", action: match).disabled(!library.canEdit)
            if library.recipe.film.monochrome { Text("The selected film is monochrome. Choose a color film to match a reference’s palette.").font(.caption).foregroundStyle(.secondary) }
            ScannerControls()
            DisclosureGroup("Color details") {
                VStack(spacing: 16) {
                    RecipeSlider(title: "Faded blacks", key: \.fade)
                    RecipeSlider(title: "Black depth", key: \.blackPoint)
                    RecipeSlider(title: "Cross-process", key: \.crossProcess)
                    RecipeSlider(title: "Shadow hue", key: \.shadowHue, multiplier: 360, suffix: "°", hue: true)
                    RecipeSlider(title: "Shadow color", key: \.shadowTone)
                    RecipeSlider(title: "Highlight hue", key: \.highlightHue, multiplier: 360, suffix: "°", hue: true)
                    RecipeSlider(title: "Highlight color", key: \.highlightTone)
                }.padding(.top, 14)
            }
        }
    }
    private var texture: some View {
        VStack(alignment: .leading, spacing: 18) {
            RecipeSlider(title: "Grain amount", key: \.grain, range: 0...8, suffix: "%")
            RecipeSlider(title: "Fine ↔ Coarse", key: \.grainSize, range: 0.5...8, multiplier: 1, format: "%.1f", suffix: "×")
            Picker("Film format", selection: Binding(get: { library.recipe.development.format }, set: { value in library.change { $0.development.format = value } })) {
                Text("35mm").tag("35mm"); Text("Medium format").tag("120"); Text("Small format").tag("110")
            }.disabled(!library.canEdit)
            Toggle("Show 100% loupe", isOn: $library.loupeVisible)
            TextureLoupe()
            Text("Move the target on the photograph to inspect texture at 100%. The full composition stays in place.").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Grain details") {
                VStack(spacing: 16) {
                    RecipeSlider(title: "Image-aware grain", key: \.development.adaptiveGrain, suffix: "%")
                    RecipeSlider(title: "Grain color", key: \.development.grainColor, suffix: "%")
                }.padding(.top, 14)
            }
        }
    }
    private var glow: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Effect", selection: $library.glowTool) { ForEach(GlowTool.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            switch library.glowTool {
            case .halation:
                RecipeSlider(title: "Amount", key: \.halation, range: 0...2)
                Toggle("Edge-aware halation", isOn: Binding(get: { library.recipe.development.advancedHalation > 0 }, set: { value in library.change { $0.development.advancedHalation = value ? 1 : 0 } }))
                RecipeSlider(title: "Spread", key: \.development.halationSpread).disabled(library.recipe.development.advancedHalation == 0)
                Button(library.directAdjustment ? "Done choosing highlight" : "Choose a highlight on image", action: library.startDirectAdjustment).disabled(!library.canEdit)
                Text("Choose a bright light to suggest its threshold. Drag sideways to change spread. This creates glow around qualifying lights throughout the image.").font(.caption).foregroundStyle(.secondary)
                if library.recipe.development.advancedHalation == 0 { Text("Stock glow is active. Enable Edge-aware halation to use spread and threshold controls on any film.").font(.caption).foregroundStyle(.secondary) }
                DisclosureGroup("Halation details") {
                    VStack(spacing: 16) {
                        RecipeSlider(title: "Edge intensity", key: \.development.advancedHalation)
                        RecipeSlider(title: "Highlight threshold", key: \.development.halationThreshold, range: 0.1...0.95, suffix: "%")
                        RecipeSlider(title: "Halo color", key: \.development.halationHue, multiplier: 360, suffix: "°", hue: true)
                    }.padding(.top, 14)
                }
            case .bloom:
                RecipeSlider(title: "Amount", key: \.bloom)
                RecipeSlider(title: "Spread", key: \.bloomRadius)
            case .leak:
                RecipeSlider(title: "Amount", key: \.lightLeak)
                RecipeSlider(title: "Spread", key: \.leakSize)
                Button(library.placingLight ? "Done placing light" : "Place light on image") {
                    library.directAdjustment = false; library.editingMask = false; library.placingLight.toggle()
                    if library.placingLight { library.comparisonMode = .developed; library.zoom = false; if library.recipe.lightLeak == 0 { library.change { $0.lightLeak = 0.4 } } }
                }.disabled(!library.canEdit)
                RecipeSlider(title: "Light color", key: \.leakHue, multiplier: 360, suffix: "°", hue: true)
                DisclosureGroup("Precise position") {
                    VStack(spacing: 16) { RecipeSlider(title: "Horizontal", key: \.leakX); RecipeSlider(title: "Vertical", key: \.leakY) }.padding(.top, 14)
                }
            }
            RecipeSlider(title: "Vignette", key: \.vignette, range: 0...2, multiplier: 50)
        }
    }
}
struct TextureLoupe: View {
    @EnvironmentObject var library: Library
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        if library.loupeVisible {
            VStack(alignment: .leading, spacing: 10) {
                Text("100% · CURRENT EDIT").font(.system(size: 10)).foregroundStyle(.secondary)
                if let image = library.loupeImage {
                    Image(nsImage: image).resizable().interpolation(.none)
                        .frame(width: image.size.width / displayScale, height: image.size.height / displayScale)
                        .accessibilityLabel("Texture loupe at one image pixel per display pixel")
                } else { Text("Developing texture…").font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Text("Position").font(.caption)
                    Slider(value: Binding(get: { library.loupePoint.x }, set: { library.loupePoint.x = $0 }), in: 0...1).accessibilityLabel("Loupe horizontal position")
                    Slider(value: Binding(get: { library.loupePoint.y }, set: { library.loupePoint.y = $0 }), in: 0...1).accessibilityLabel("Loupe vertical position")
                }
            }
        }
    }
}

struct ImageAdjustmentSurface: View {
    @EnvironmentObject var library: Library
    let size: CGSize
    @State private var start: Recipe?
    @State private var target: LightRegion = .exposure
    @State private var point: CGPoint?
    @State private var hint = ""
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle())
            if let point {
                Image(systemName: "scope").foregroundStyle(Color.accent).font(.title2).position(point)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(library.activeTool == .light ? "WHOLE IMAGE · " + target.rawValue.uppercased() : "WHOLE IMAGE · HIGHLIGHT GLOW").font(.system(size: 10, weight: .medium))
                Text(hint.isEmpty ? (library.activeTool == .light ? "Drag up to brighten · down to darken · Esc to finish" : "Choose a bright light · drag sideways for spread · Esc to finish") : hint).font(.caption)
            }.padding(9).background(.black.opacity(0.75)).padding(8).allowsHitTesting(false)
        }.frame(width: size.width, height: size.height)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if start == nil {
                    start = library.recipe; library.adjustmentGesture(true); point = value.startLocation; hint = ""
                    let p = MaskPoint(x: value.startLocation.x / size.width, y: value.startLocation.y / size.height)
                    if library.activeTool == .light {
                        target = library.lightRegion
                        if library.autoLightTarget, let luminance = library.pickLuminance(p) {
                            target = luminance < 0.35 ? .shadows : luminance > 0.7 ? .highlights : .exposure
                        }
                    } else {
                        guard let l = library.pickLuminance(p), l > 0.55 else { hint = "Choose a brighter light. No settings changed."; return }
                        let threshold = min(0.95, max(0.1, pow(l, 2.2) * 0.8))
                        library.change { $0.development.advancedHalation = 1; $0.development.halationThreshold = threshold; if $0.halation == 0 { $0.halation = 1 } }
                    }
                }
                guard let start else { return }
                if library.activeTool == .light {
                    let key = target.key, bounds = target.bounds
                    let change = -Double(value.translation.height) / Double(max(100, size.height)) * (target == .exposure ? 4 : 2)
                    library.change { $0[keyPath: key] = min(bounds.upperBound, max(bounds.lowerBound, start[keyPath: key] + change)) }
                    hint = target.rawValue + (target == .exposure ? String(format: " %+.2f EV", library.recipe[keyPath: key]) : String(format: " %+.0f", library.recipe[keyPath: key] * 100))
                } else if !hint.hasPrefix("Choose a brighter") {
                    library.change { $0.development.halationSpread = min(1, max(0, start.development.halationSpread + Double(value.translation.width / max(100, size.width)) * 2)) }
                    hint = "Spread " + String(format: "%.0f%%", library.recipe.development.halationSpread * 100)
                }
            }.onEnded { _ in start = nil; library.adjustmentGesture(false) })
            .onDisappear { start = nil; library.adjustmentGesture(false) }
    }
}
struct TextureTarget: View {
    @EnvironmentObject var library: Library
    let size: CGSize
    var body: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            Rectangle().stroke(Color.accent, lineWidth: 1).frame(width: 34, height: 34)
                .position(x: library.loupePoint.x * size.width, y: library.loupePoint.y * size.height)
            VStack { HStack { Text("MOVE TARGET TO INSPECT TEXTURE · 100% LOUPE").font(.system(size: 9)).padding(8).background(.black.opacity(0.7)); Spacer() }; Spacer() }.allowsHitTesting(false)
        }.frame(width: size.width, height: size.height)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                library.loupePoint = MaskPoint(x: min(1, max(0, value.location.x / size.width)), y: min(1, max(0, value.location.y / size.height)))
            })
    }
}
struct VersionMenu: View {
    @EnvironmentObject var library: Library
    var body: some View {
        Menu {
            if library.selected?.versions.isEmpty != false { Text("Keep a version before exploring") }
            ForEach(library.selected?.versions ?? []) { version in
                Menu(version.name) {
                    Button("Compare with current edit") { library.comparisonVersionID = version.id; library.comparisonMode = .sideBySide }
                    Button("Restore settings") { library.restoreVersion(version.id) }
                    Button("Delete version", role: .destructive) { library.deleteVersion(version.id) }
                }
            }
        } label: { Label("Versions", systemImage: "square.on.square") }.menuStyle(.borderlessButton).fixedSize()
    }
}
