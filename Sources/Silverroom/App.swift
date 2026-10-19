import SwiftUI
import AppKit

@main struct SilverroomApp: App {
    @StateObject private var library = Library()
    var body: some Scene {
        Window("Romeling Silverroom", id: "darkroom") {
            DarkroomView().environmentObject(library)
                .frame(minWidth: 1000, minHeight: 680)
                .preferredColorScheme(.dark)
                .onOpenURL { library.add([$0]) }
        }
        .defaultSize(width: 1380, height: 900)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Photographs…", action: library.open).keyboardShortcut("o")
                Menu("Export Photograph") {
                    Button("JPEG…") { library.export(format: "jpg") }.keyboardShortcut("e", modifiers: [.command, .shift])
                    Button("16-bit TIFF…") { library.export(format: "tiff") }
                    Button("PNG…") { library.export(format: "png") }
                }.disabled(!library.canExport || library.exporting)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo", action: library.undo).keyboardShortcut("z").disabled(library.undoStack.isEmpty)
                Button("Redo", action: library.redo).keyboardShortcut("z", modifiers: [.command, .shift]).disabled(library.redoStack.isEmpty)
            }
            CommandGroup(after: .toolbar) {
                Button(library.inspectorVisible ? "Hide Adjustments" : "Show Adjustments") { library.inspectorVisible.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
                Button(library.sessionVisible ? "Hide Session" : "Show Session") { library.sessionVisible.toggle() }.keyboardShortcut("s", modifiers: [.command, .option])
            }
            CommandMenu("Develop") {
                Button("Original / Developed") { library.toggleOriginal() }.keyboardShortcut("b", modifiers: []).disabled(!library.canEdit)
                Button("Fit / 100%") { library.zoom.toggle() }.keyboardShortcut("1").disabled(!library.canEdit)
                Button("Zoom In") { library.stepZoom(1) }.keyboardShortcut("=").disabled(!library.canEdit)
                Button("Zoom Out") { library.stepZoom(-1) }.keyboardShortcut("-").disabled(!library.canEdit)
                Button("Fit to Window") { library.zoomLevel = 0 }.keyboardShortcut("0").disabled(!library.canEdit)
                Button("Previous Film") { library.stepFilm(-1) }.keyboardShortcut(.upArrow, modifiers: .option).disabled(!library.canEdit)
                Button("Next Film") { library.stepFilm(1) }.keyboardShortcut(.downArrow, modifiers: .option).disabled(!library.canEdit)
                ResetSettingsMenu().environmentObject(library)
                Divider()
                Button("Close Image", action: library.removeSelected).keyboardShortcut(.delete, modifiers: .command).disabled(library.selected == nil)
            }
        }
    }
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
    static let room = Color(hex: 0x151616)
    static let panel = Color(hex: 0x1D1E1E)
    static let subtle = Color(hex: 0x9A9C98)
    static let accent = Color(hex: 0xD3C4A5)
}
struct RomelingMark: View {
    static let image = NSImage(contentsOf: Bundle.module.url(forResource: "romeling-logo", withExtension: "svg")!)!
    var body: some View { Image(nsImage: Self.image).renderingMode(.template).resizable().scaledToFit().foregroundStyle(Color.accent).accessibilityLabel("Romeling") }
}

struct Caption: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(Color.subtle) }
}
struct DarkroomView: View {
    @EnvironmentObject var library: Library
    @Environment(\.displayScale) private var displayScale
    @FocusState private var previewFocused: Bool
    @State private var dropTarget = false
    @State private var savingRecipe = false
    @State private var batchExport = false
    @State private var referencePhoto: Photograph?
    @State private var recipeName = ""
    @State private var browsingFilms = false
    private var workspace: some View {
        VStack(spacing: 0) {
            canvas
            if library.sessionVisible && !library.photos.isEmpty {
                Divider()
                filmstrip
            }
            Divider()
            footer
        }
        .background(Color.room)
        .navigationTitle(library.selected?.name ?? "Romeling Silverroom")
        .inspector(isPresented: $library.inspectorVisible) {
            WorkingInspector(save: { recipeName = library.recipe.film.name + " · Custom"; savingRecipe = true }, match: { referencePhoto = library.selected })
                .padding(12)
                .background(Color.room)
                .inspectorColumnWidth(min: 320, ideal: 350, max: 420)
        }
        .toolbar { darkroomToolbar }
        .controlSize(.regular)
    }
    var body: some View {
        workspace
        .onChange(of: library.selectedID) { _, id in previewFocused = id != nil }
        .onChange(of: library.zoomLevel) { old, level in if level != 0 { library.placingLight = false; library.editingMask = false; library.directAdjustment = false }; if old == 0 || level == 0 { library.render() } }
        .onChange(of: library.compare) { _, comparing in if comparing { library.placingLight = false; library.editingMask = false; library.directAdjustment = false } }
        .onChange(of: library.recipe.masks.map(\.id)) { _, ids in
            if let id = library.activeMaskID, !ids.contains(id) { library.activeMaskID = nil; library.editingMask = false }
        }
        .onChange(of: library.directAdjustment) { _, active in if active { previewFocused = true } }
        .onChange(of: library.editingMask) { _, active in if active { previewFocused = true } }
        .onChange(of: library.placingLight) { _, active in if active { previewFocused = true } }
        .onChange(of: library.glowTool) { _, _ in library.directAdjustment = false; library.placingLight = false }
        .onChange(of: library.comparisonVersionID) { _, _ in library.versionPreview = nil; library.render() }
        .onChange(of: library.bypassedTool) { _, _ in library.render() }
        .onChange(of: library.loupePoint) { _, _ in library.render() }
        .onChange(of: library.loupeVisible) { _, _ in library.render() }
        .onChange(of: library.activeMaskID) { _, _ in library.render() }
        .onChange(of: library.showMask) { _, _ in library.render() }
        .tint(Color.accent)
        .alert("Couldn’t complete that", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button("OK") { library.error = nil }
        } message: { Text(library.error ?? "") }
        .sheet(item: $referencePhoto) { photo in ReferenceMatchView(photo: photo).environmentObject(library) }
        .sheet(isPresented: $batchExport) { BatchExportView().environmentObject(library) }
        .sheet(isPresented: $savingRecipe) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Save a recipe").font(.title2)
                Text("Keep this film and its adjustments for another photograph.").foregroundStyle(.secondary)
                TextField("Recipe name", text: $recipeName).textFieldStyle(.roundedBorder)
                HStack { Button("Cancel") { savingRecipe = false }.keyboardShortcut(.cancelAction); Spacer(); Button("Save Recipe") { library.saveRecipe(name: recipeName); savingRecipe = false }.keyboardShortcut(.defaultAction).disabled(recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.padding(28).frame(width: 380)
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTarget, perform: importDrop)
        .overlay { if dropTarget { Rectangle().stroke(Color.accent, lineWidth: 2).padding(5).allowsHitTesting(false) } }
    }
    private func importDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in library.add([url]) }
            }
        }
        return !providers.isEmpty
    }
    @ToolbarContentBuilder private var darkroomToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: library.open) { Label("Import", systemImage: "plus").labelStyle(.titleAndIcon) }
                .help("Import photographs · ⌘O")
        }
        ToolbarItem(placement: .principal) {
            Button { browsingFilms = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.filters")
                    Text(library.recipe.film.name).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }.padding(.horizontal, 6).frame(minHeight: 32, maxHeight: 32).frame(maxWidth: 190)
            }
            .help("Choose film · ⌥↑ / ⌥↓ to switch quickly")
            .disabled(!library.canEdit)
            .popover(isPresented: $browsingFilms) {
                FilmBrowser().environmentObject(library)
            }
        }
        ToolbarItem(placement: .automatic) { PreviewControls().fixedSize() }
        ToolbarItem(placement: .automatic) {
            Menu {
                Button("Keep Version", action: library.keepVersion).disabled(!library.canExport)
                VersionMenu()
                ResetSettingsMenu()
                Divider()
                Button("Batch Export…") { batchExport = true }
                    .disabled(library.photos.isEmpty || library.exporting || library.bypassedTool != nil)
                Button("Close Image", action: library.removeSelected).disabled(library.selected == nil)
            } label: { Label("More", systemImage: "ellipsis.circle") }
            .help("Versions, reset, batch export and close image")
        }
        ToolbarItem(placement: .automatic) {
            Menu {
                Button("JPEG · 95% quality") { library.export(format: "jpg") }
                Button("TIFF · 16-bit") { library.export(format: "tiff") }
                Button("PNG · Lossless") { library.export(format: "png") }
            } label: { Label("Export", systemImage: "square.and.arrow.up").labelStyle(.titleAndIcon) }
                .disabled(!library.canExport || library.exporting).help("Export photograph")
        }
        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $library.sessionVisible) { Label("Session", systemImage: "rectangle.bottomthird.inset.filled") }
                .help("Show or hide session · ⌥⌘S")
        }
        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $library.inspectorVisible) { Label("Adjustments", systemImage: "sidebar.right") }
                .help("Show or hide adjustments · ⌥⌘I")
        }
    }

    private var canvas: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: 0x101111)
                if let image = library.preview ?? library.original {
                    if library.zoom && library.comparisonMode == .sideBySide, let reference = library.comparisonImage {
                        AlignedComparison(left: reference, right: image, imageSize: CGSize(width: library.size.width * library.zoomLevel / displayScale, height: library.size.height * library.zoomLevel / displayScale))
                            .overlay(alignment: .top) {
                                HStack { Text(library.referenceName.uppercased()); Spacer(); Text("CURRENT EDIT") }.font(.system(size: 10, weight: .medium)).padding(8).background(.black.opacity(0.6)).allowsHitTesting(false)
                            }
                    } else if library.zoom {
                        ScrollView([.horizontal, .vertical]) {
                            ImageComparison(image: image, size: CGSize(width: library.size.width * library.zoomLevel / displayScale, height: library.size.height * library.zoomLevel / displayScale))
                                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                        }
                    } else {
                        let ratio = image.size.width / max(1, image.size.height)
                        let availableWidth = library.comparisonMode == .sideBySide ? (proxy.size.width - 48) / 2 : proxy.size.width - 32
                        let w = min(max(1, availableWidth), max(1, proxy.size.height - 32) * ratio)
                        ImageComparison(image: image, size: CGSize(width: w, height: w / ratio))
                    }
                } else if library.busy {
                    ProgressView("Opening photograph…").controlSize(.small)
                } else if library.selected != nil {
                    VStack(spacing: 16) { Image(systemName: "photo.badge.exclamationmark").font(.largeTitle); Text("This photograph is unavailable"); Button("Locate another photograph…", action: library.open) }.foregroundStyle(Color.subtle)
                } else {
                    VStack(spacing: 25) {
                        Image(systemName: "camera.aperture").font(.system(size: 52, weight: .ultraLight)).foregroundStyle(Color.accent)
                        VStack(spacing: 12) {
                            Text("Make light feel different.").font(.system(size: 30, weight: .light)).tracking(-0.6)
                            Text("Bring a photograph into the darkroom.\nFind its character in film.").font(.system(size: 13)).foregroundStyle(Color.subtle).multilineTextAlignment(.center).lineSpacing(5)
                        }
                        Button(action: library.open) { Text("Import photographs").padding(.horizontal, 18).padding(.vertical, 9) }.buttonStyle(.borderedProminent).foregroundStyle(Color.room)
                        Caption(text: "DROP RAW, JPEG, HEIF OR TIFF HERE")
                    }
                }
            }
        }
            .focusable().focused($previewFocused)
            .onTapGesture(count: 2) { if library.canEdit && !library.placingLight && !library.editingMask && !library.directAdjustment && library.activeTool != .texture && !library.comparisonMode.isSplit { library.zoom.toggle() } }
            .simultaneousGesture(TapGesture().onEnded { previewFocused = true })
            .onKeyPress(.escape) {
                library.directAdjustment = false; library.editingMask = false; library.placingLight = false; library.explorationBase = nil
                return .handled
            }
            .onKeyPress(.upArrow) { guard library.canEdit else { return .ignored }; library.stepFilm(-1); return .handled }
            .onKeyPress(.downArrow) { guard library.canEdit else { return .ignored }; library.stepFilm(1); return .handled }
            .help("↑ / ↓ to switch films when the preview is focused. Scroll to pan when zoomed.")
    }
    private var filmstrip: some View {
        HStack(spacing: 18) {
            Text("\(library.photos.count) \(library.photos.count == 1 ? "photo" : "photos")").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(library.photos) { photo in
                        Button { library.select(photo.id) } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    Rectangle().fill(Color.panel)
                                    if let thumb = photo.thumbnail { Image(nsImage: thumb).resizable().scaledToFill() } else { Image(systemName: "photo").foregroundStyle(Color.subtle) }
                                }.frame(width: 84, height: 56).clipped().overlay(Rectangle().stroke(library.selectedID == photo.id ? Color.accent : .clear, lineWidth: 2))
                                Text(photo.name).font(.system(size: 9)).lineLimit(1).frame(width: 84)
                            }
                        }.buttonStyle(.plain).accessibilityLabel("Select \(photo.name)")
                        .overlay(alignment: .topTrailing) {
                            Button { library.close(photo.id) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                                    .frame(width: 20, height: 20).background(.black.opacity(0.75), in: Circle())
                            }.buttonStyle(.plain).padding(3).help("Close \(photo.name)")
                                .accessibilityLabel("Close \(photo.name)")
                        }
                    }
                    Button(action: library.open) { Image(systemName: "plus").frame(width: 54, height: 56).overlay(Rectangle().stroke(.white.opacity(0.14))) }.buttonStyle(.plain).help("Import photographs")
                }.padding(3)
            }.scrollIndicators(.hidden)
        }.padding(.horizontal, 16).frame(height: 84)
    }
    private var footer: some View {
        HStack(spacing: 8) {
            if library.busy || library.exporting { ProgressView().controlSize(.mini).scaleEffect(0.7) } else { Circle().fill(Color.subtle).frame(width: 4, height: 4) }
            Text(library.status).font(.system(size: 10)).foregroundStyle(Color.subtle)
            Spacer()
            if library.size.width > 0 {
                Text("\(Int(library.size.width)) × \(Int(library.size.height))").font(.system(size: 10)).foregroundStyle(Color.subtle)
            }
        }.padding(.horizontal, 16).frame(height: 22)
    }
}

struct ResetSettingsMenu: View {
    @EnvironmentObject var library: Library
    var body: some View {
        Menu {
            Button("Reset " + library.activeTool.rawValue + " controls") { library.resetTool() }
            if let id = library.activeMaskID, library.activeTool == .local {
                Button("Reset selected mask adjustments") {
                    library.editMask(id) { $0.exposure = 0; $0.warmth = 0; $0.saturation = 1; $0.contrast = 1; $0.softness = 0 }
                }
            }
            Divider()
            Button("Reset Adjustments · Keep Film") { library.reset(keepingFilm: true) }
            Button("Reset All Settings") { library.reset() }
        } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
        .disabled(!library.canEdit)
        .help("Reset this photograph’s settings · Undo with ⌘Z")
    }
}
