import SwiftUI

/// Starting points change finishing only; exposure, white balance and film stay yours.
enum Treatment: String, CaseIterable {
    case clean = "Clean finish"
    case amber = "Amber & cyan"
    case faded = "Faded print"
    case nocturne = "Nocturne"
    case sunwash = "Sun wash"
    func apply(to r: inout Recipe) {
        r.fade = 0; r.blackPoint = 0; r.crossProcess = 0
        r.shadowHue = 0.55; r.highlightHue = 0.10
        r.shadowTone = 0; r.highlightTone = 0
        r.bloom = 0; r.bloomRadius = 0.35
        r.lightLeak = 0; r.leakX = 0.05; r.leakY = 0.35; r.leakSize = 0.5; r.leakHue = 0.06
        r.grainSize = 1
        switch self {
        case .clean: break
        case .amber: r.shadowTone = 0.65; r.highlightTone = 0.55; r.blackPoint = 0.15
        case .faded: r.fade = 0.65; r.highlightTone = 0.3; r.grainSize = 1.8
        case .nocturne: r.shadowHue = 0.64; r.shadowTone = 0.75; r.highlightHue = 0.91; r.highlightTone = 0.35; r.bloom = 0.35; r.blackPoint = 0.3
        case .sunwash: r.lightLeak = 0.5; r.bloom = 0.2; r.fade = 0.2; r.highlightTone = 0.3
        }
    }
}

struct RecipeSlider: View {
    @EnvironmentObject var library: Library
    let title: String
    let key: WritableKeyPath<Recipe, Double>
    var range: ClosedRange<Double> = 0...1
    var multiplier: Double = 100
    var format = "%.0f"
    var suffix = ""
    var hue = false
    var body: some View {
        VStack(spacing: 7) {
            HStack {
                if hue { Circle().fill(Color(hue: library.recipe[keyPath: key], saturation: 0.7, brightness: 0.9)).frame(width: 8, height: 8).accessibilityHidden(true) }
                Text(title).font(.system(size: 12))
                Spacer()
                Text(String(format: format, library.recipe[keyPath: key] * multiplier) + suffix).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.subtle)
            }
            Slider(value: Binding(get: { library.recipe[keyPath: key] }, set: { value in library.change { $0[keyPath: key] = value } }), in: range, onEditingChanged: library.adjustmentGesture)
                .controlSize(.small).accessibilityLabel(title).disabled(!library.canEdit)
        }
    }
}

struct ColorField: View {
    @EnvironmentObject var library: Library
    @State private var dragging = false
    @State private var precision = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Color balance").font(.system(size: 11)); Spacer(); Button("Neutral") { library.change { $0.warmth = 0; $0.tint = 0 } }.buttonStyle(.plain).font(.system(size: 10)).disabled(!library.canEdit) }
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x3D6576), Color(hex: 0x8C7045)], startPoint: .leading, endPoint: .trailing)
                    LinearGradient(colors: [.purple.opacity(0.35), .clear, .green.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
                    Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                    VStack { Text("MAGENTA"); Spacer(); Text("GREEN") }.font(.system(size: 8)).tracking(1).padding(7).foregroundStyle(.white.opacity(0.7))
                    HStack { Text("COOL"); Spacer(); Text("WARM") }.font(.system(size: 8)).tracking(1).padding(8).foregroundStyle(.white.opacity(0.7))
                    Circle().strokeBorder(.white, lineWidth: 2).background(Circle().fill(.black.opacity(0.25))).frame(width: 13, height: 13)
                        .position(x: 8 + (library.recipe.warmth + 1) / 2 * (geometry.size.width - 16), y: 8 + (1 - library.recipe.tint) / 2 * (geometry.size.height - 16))
                }.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        if !dragging { dragging = true; library.adjustmentGesture(true) }
                        let x = min(1, max(0, (value.location.x - 8) / (geometry.size.width - 16)))
                        let y = min(1, max(0, (value.location.y - 8) / (geometry.size.height - 16)))
                        library.change { $0.warmth = x * 2 - 1; $0.tint = 1 - y * 2 }
                    }.onEnded { _ in dragging = false; library.adjustmentGesture(false) })
                    .allowsHitTesting(library.canEdit).opacity(library.canEdit ? 1 : 0.4)
                    .accessibilityElement(children: .ignore).accessibilityLabel("Color balance field. Use Warmth and Tint under Precision controls for keyboard adjustment.")
                    .help("Drag to balance warmth and tint. Use Precision controls for individual sliders.")
            }.frame(height: 112)
            DisclosureGroup("Precision controls", isExpanded: $precision) {
                VStack(spacing: 14) {
                    RecipeSlider(title: "Warmth", key: \.warmth, range: -1...1, format: "%+.0f")
                    RecipeSlider(title: "Tint", key: \.tint, range: -1...1, format: "%+.0f")
                }.padding(.top, 12)
            }.font(.system(size: 10)).foregroundStyle(Color.subtle)
        }
    }
}

struct FilmBrowser: View {
    @EnvironmentObject var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var category = "All"
    var filtered: [Film] {
        Film.all.filter { film in
            (search.isEmpty || "\(film.maker) \(film.name) \(film.kind)".localizedCaseInsensitiveContains(search)) &&
            (category == "All" || (category == "Monochrome" ? film.monochrome : category == "Experimental" ? film.kind == "EXPERIMENTAL COLOR" : !film.monochrome && film.kind != "EXPERIMENTAL COLOR"))
        }.sorted { ($0.maker, $0.name) < ($1.maker, $1.name) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Caption(text: "THE FILM LIBRARY"); Spacer(); Text("\(Film.all.count) stocks").font(.system(size: 11)).foregroundStyle(Color.subtle) }
            TextField("Search films or makers", text: $search).textFieldStyle(.roundedBorder).accessibilityLabel("Search films or makers")
            Picker("Film type", selection: $category) { ForEach(["All", "Color", "Monochrome", "Experimental"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(filtered) { film in
                        Button {
                            library.change { $0.filmID = film.id }
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Rectangle().fill(Color(hex: film.color)).frame(width: 3, height: 36)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(film.name).font(.system(size: 13, weight: .medium))
                                    Text(film.maker + "  /  " + film.kind).font(.system(size: 8)).tracking(0.8).foregroundStyle(Color.subtle)
                                }
                                Spacer()
                                Text(film.iso).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.subtle)
                                Image(systemName: "checkmark").font(.system(size: 10)).opacity(library.recipe.filmID == film.id ? 1 : 0)
                            }.padding(10).contentShape(Rectangle()).background(library.recipe.filmID == film.id ? .white.opacity(0.07) : .clear)
                        }.buttonStyle(.plain).disabled(!library.canEdit).help(film.note)
                    }
                    if filtered.isEmpty { Text("No films match. Try another name or film type.").font(.system(size: 12)).foregroundStyle(Color.subtle).padding(.vertical, 30) }
                }
            }
            HStack { Text("Film-inspired interpretations").font(.system(size: 10)).foregroundStyle(Color.subtle); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
        }.padding(20).frame(width: 430, height: 460).background(Color.panel)
    }
}

struct DevelopmentInspector: View {
    @EnvironmentObject var library: Library
    var save: () -> Void
    @State private var browsing = false
    @State private var toneExpanded = false
    @State private var splitExpanded = false
    @State private var textureExpanded = true
    @State private var lightExpanded = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Caption(text: "01 / EMULSION"); Spacer(); Text("\(Film.all.count) films").font(.system(size: 10)).foregroundStyle(Color.subtle) }
                Button { browsing = true } label: {
                    HStack(spacing: 12) {
                        Rectangle().fill(Color(hex: library.recipe.film.color)).frame(width: 3, height: 38)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(library.recipe.film.name).font(.system(size: 18, weight: .light))
                            Text(library.recipe.film.maker + "  /  ISO " + library.recipe.film.iso).font(.system(size: 9)).tracking(1).foregroundStyle(Color.subtle)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).help("Browse and search all film stocks").accessibilityLabel("Browse films. Selected \(library.recipe.film.name)")
                    .focusable().onKeyPress(.upArrow) { guard library.canEdit else { return .ignored }; library.stepFilm(-1); return .handled }
                    .onKeyPress(.downArrow) { guard library.canEdit else { return .ignored }; library.stepFilm(1); return .handled }
                    .popover(isPresented: $browsing, arrowEdge: .top) { FilmBrowser().environmentObject(library) }
                HStack {
                    Button { library.stepFilm(-1) } label: { Label("Previous", systemImage: "chevron.up").frame(minHeight: 24) }.help("Previous film · ⌥↑")
                    Spacer()
                    Button { library.stepFilm(1) } label: { Label("Next", systemImage: "chevron.down").frame(minHeight: 24) }.help("Next film · ⌥↓")
                }.buttonStyle(.borderless).disabled(!library.canEdit)
                Text(library.recipe.film.note).font(.system(size: 11)).foregroundStyle(Color.subtle).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                RecipeSlider(title: "Film strength", key: \.amount, suffix: "%")
                DevelopmentControls()
                Divider()
                Caption(text: "02 / CHARACTER")
                Menu {
                    ForEach(Treatment.allCases, id: \.self) { treatment in Button(treatment.rawValue) { library.change { treatment.apply(to: &$0) } } }
                } label: { Label("Apply a creative treatment", systemImage: "wand.and.stars") }.disabled(!library.canEdit).help("Starting points for finishing. Your film, exposure and white balance stay unchanged.")
                RecipeSlider(title: "Exposure", key: \.exposure, range: -3...3, multiplier: 1, format: "%+.2f", suffix: " EV")
                ColorField()
                DisclosureGroup("Tone & color response", isExpanded: $toneExpanded) {
                    VStack(spacing: 18) {
                        RecipeSlider(title: "Contrast", key: \.contrast, range: 0.7...1.3)
                        RecipeSlider(title: "Saturation", key: \.saturation, range: 0...2)
                        RecipeSlider(title: "Highlight recovery", key: \.highlights)
                        RecipeSlider(title: "Shadow lift", key: \.shadows)
                        RecipeSlider(title: "Faded blacks", key: \.fade)
                        RecipeSlider(title: "Black depth", key: \.blackPoint)
                        RecipeSlider(title: "Cross-process", key: \.crossProcess)
                    }.padding(.top, 16)
                }.font(.system(size: 12))
                DisclosureGroup("Split toning", isExpanded: $splitExpanded) {
                    VStack(spacing: 18) {
                        Text("Color the shadows and highlights independently. Set an amount to bring each hue into the image.").font(.system(size: 10)).foregroundStyle(Color.subtle)
                        RecipeSlider(title: "Shadow hue", key: \.shadowHue, multiplier: 360, suffix: "°", hue: true)
                        RecipeSlider(title: "Shadow color", key: \.shadowTone)
                        RecipeSlider(title: "Highlight hue", key: \.highlightHue, multiplier: 360, suffix: "°", hue: true)
                        RecipeSlider(title: "Highlight color", key: \.highlightTone)
                    }.padding(.top, 16)
                }.font(.system(size: 12))
                Divider()
                Caption(text: "03 / LIGHT & SURFACE")
                DisclosureGroup("Light leaks & bloom", isExpanded: $lightExpanded) {
                    VStack(spacing: 18) {
                        RecipeSlider(title: "Bloom", key: \.bloom)
                        RecipeSlider(title: "Bloom spread", key: \.bloomRadius)
                        RecipeSlider(title: "Light leak", key: \.lightLeak)
                        Button {
                            library.editingMask = false; library.placingLight.toggle()
                            if library.placingLight {
                                library.compare = false; library.zoom = false
                                if library.recipe.lightLeak == 0 { library.change { $0.lightLeak = 0.4 } }
                            }
                        } label: { Label(library.placingLight ? "Done placing light" : "Place light on photograph", systemImage: "scope") }
                            .disabled(!library.canEdit).help("Click or drag on the photograph to position the light leak.")
                        RecipeSlider(title: "Leak hue", key: \.leakHue, multiplier: 360, suffix: "°", hue: true)
                        RecipeSlider(title: "Leak spread", key: \.leakSize)
                        DisclosureGroup("Position precisely") {
                            VStack(spacing: 18) {
                                RecipeSlider(title: "Leak horizontal position", key: \.leakX, suffix: "%")
                                RecipeSlider(title: "Leak vertical position", key: \.leakY, suffix: "%")
                            }.padding(.top, 16)
                        }.font(.system(size: 10))
                    }.padding(.top, 16)
                }.font(.system(size: 12))
                DisclosureGroup("Grain, halation & vignette", isExpanded: $textureExpanded) {
                    VStack(spacing: 18) {
                        RecipeSlider(title: "Grain amount", key: \.grain, range: 0...8, suffix: "%")
                        RecipeSlider(title: "Grain size", key: \.grainSize, range: 0.5...8, multiplier: 1, format: "%.1f", suffix: "×")
                        GrainControls()
                        RecipeSlider(title: "Halation", key: \.halation, range: 0...2)
                        RecipeSlider(title: "Vignette", key: \.vignette, range: 0...2, multiplier: 50)
                        Text("Grain amount: 100% is the stock’s default, up to 800% for heavy texture. Grain size reaches 8×. Judge texture at 100% zoom. Film strength also affects grain.").font(.system(size: 10)).foregroundStyle(Color.subtle)
                    }.padding(.top, 16)
                }.font(.system(size: 12))
                HalationControls()
                Divider()
                ScannerControls()
                LocalMaskControls()
                Divider()
                HStack {
                    Menu("Recipes") {
                        if library.recipes.isEmpty { Text("No saved recipes") }
                        ForEach(library.recipes) { saved in Button(saved.name) { library.change { $0 = saved.recipe } } }
                    }.disabled(!library.canEdit)
                    Button("Save…", action: save).disabled(!library.canEdit)
                }
                Text("Film-inspired profiles. Crafted interpretations, not calibrated reproductions.").font(.system(size: 10)).foregroundStyle(Color.subtle).lineSpacing(3)
            }.padding(24)
        }.background(Color.panel)
    }
}

struct LightPlacement: View {
    @EnvironmentObject var library: Library
    let size: CGSize
    @State private var dragging = false
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle())
            Image(systemName: "scope").font(.system(size: 24, weight: .light)).foregroundStyle(.white).shadow(color: .black, radius: 2)
                .position(x: library.recipe.leakX * size.width, y: library.recipe.leakY * size.height)
            Text("CLICK OR DRAG TO PLACE LIGHT").font(.system(size: 9)).tracking(1).padding(9).background(.black.opacity(0.6)).padding(8)
        }.frame(width: size.width, height: size.height)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if !dragging { dragging = true; library.adjustmentGesture(true) }
                library.change {
                    $0.leakX = min(1, max(0, value.location.x / size.width))
                    $0.leakY = min(1, max(0, value.location.y / size.height))
                }
            }.onEnded { _ in dragging = false; library.adjustmentGesture(false) })
            .accessibilityLabel("Place light. Horizontal and vertical position sliders are also available in the inspector.")
            .onDisappear { if dragging { library.adjustmentGesture(false); dragging = false } }
    }
}
