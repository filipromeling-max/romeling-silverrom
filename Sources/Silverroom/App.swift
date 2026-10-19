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
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Photographs…", action: library.open).keyboardShortcut("o")
                Menu("Export Photograph") {
                    Button("JPEG…") { library.export(format: "jpg") }.keyboardShortcut("e", modifiers: [.command, .shift])
                    Button("16-bit TIFF…") { library.export(format: "tiff") }
                    Button("PNG…") { library.export(format: "png") }
                }.disabled(!library.canEdit || library.exporting)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo", action: library.undo).keyboardShortcut("z").disabled(library.undoStack.isEmpty)
                Button("Redo", action: library.redo).keyboardShortcut("z", modifiers: [.command, .shift]).disabled(library.redoStack.isEmpty)
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
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    imageHeader
                    PreviewControls().padding(.horizontal, 24).frame(height: 42)
                    canvas
                    filmstrip
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                DevelopmentInspector { recipeName = library.recipe.film.name + " · Custom"; savingRecipe = true }.frame(width: 320)
            }
            Divider()
            footer
        }
        .background(Color.room)
        .onChange(of: library.selectedID) { _, id in previewFocused = id != nil }
        .onChange(of: library.zoomLevel) { old, level in if level != 0 { library.placingLight = false; library.editingMask = false }; if old == 0 || level == 0 { library.render() } }
        .onChange(of: library.compare) { _, comparing in if comparing { library.placingLight = false; library.editingMask = false } }
        .onChange(of: library.recipe.masks.map(\.id)) { _, ids in
            if let id = library.activeMaskID, !ids.contains(id) { library.activeMaskID = nil; library.editingMask = false }
        }
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
        .onDrop(of: [.fileURL], isTargeted: $dropTarget) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }; Task { @MainActor in library.add([url]) }
                }
            }
            return !providers.isEmpty
        }
        .overlay { if dropTarget { Rectangle().stroke(Color.accent, lineWidth: 2).padding(5).allowsHitTesting(false) } }
    }
    private var header: some View {
        HStack(spacing: 20) {
            RomelingMark().frame(width: 98, height: 48)
            Text("SILVERROOM").font(.system(size: 12, weight: .medium)).tracking(3)
            Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 18)
            Caption(text: "THE DIGITAL DARKROOM")
            Spacer()
            Button { batchExport = true } label: { Label("Batch", systemImage: "square.stack") }.buttonStyle(.plain).disabled(library.photos.isEmpty || library.exporting).help("Develop and export multiple photographs")
            Button(action: library.open) { Label("Import", systemImage: "plus") }.buttonStyle(.plain).help("Import photographs · ⌘O")
            Menu {
                Button("JPEG · 95% quality") { library.export(format: "jpg") }
                Button("TIFF · 16-bit") { library.export(format: "tiff") }
                Button("PNG · Lossless") { library.export(format: "png") }
            } label: { Label(library.exporting ? "Exporting…" : "Export", systemImage: "square.and.arrow.up").padding(.horizontal, 8).padding(.vertical, 5) }
                .menuStyle(.borderlessButton).fixedSize().disabled(!library.canEdit || library.exporting)
        }.padding(.leading, 82).padding(.trailing, 24).frame(height: 64)
    }
    private var imageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(library.selected?.name ?? "Your next photograph").font(.system(size: 14, weight: .medium)).lineLimit(1)
                Caption(text: library.selected.map { $0.url.pathExtension.uppercased() + (library.size.width > 0 ? "  /  \(Int(library.size.width)) × \(Int(library.size.height))" : "") } ?? "A LITTLE LIGHT. A DIFFERENT FEELING.")
            }
            Spacer()
            if library.selected != nil {
                Button { referencePhoto = library.selected } label: { Label("Match reference", systemImage: "photo.on.rectangle") }.buttonStyle(.borderless).disabled(!library.canEdit)
                ResetSettingsMenu().menuStyle(.borderlessButton).fixedSize()
            }
        }.padding(.horizontal, 28).frame(height: 64)
    }

    private var canvas: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: 0x101111)
                if let image = library.preview ?? library.original {
                    if library.zoom {
                        ScrollView([.horizontal, .vertical]) {
                            ImageComparison(image: image, size: CGSize(width: library.size.width * library.zoomLevel / displayScale, height: library.size.height * library.zoomLevel / displayScale))
                                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                        }
                    } else {
                        let ratio = image.size.width / max(1, image.size.height)
                        let availableWidth = library.comparisonMode == .sideBySide ? (proxy.size.width - 80) / 2 : proxy.size.width - 64
                        let w = min(max(1, availableWidth), max(1, proxy.size.height - 56) * ratio)
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
        }.padding(.horizontal, 16).padding(.bottom, 16)
            .focusable().focused($previewFocused)
            .onTapGesture(count: 2) { if library.canEdit && !library.placingLight && !library.editingMask && !library.comparisonMode.isSplit { library.zoom.toggle() } }
            .simultaneousGesture(TapGesture().onEnded { previewFocused = true })
            .onKeyPress(.upArrow) { guard library.canEdit else { return .ignored }; library.stepFilm(-1); return .handled }
            .onKeyPress(.downArrow) { guard library.canEdit else { return .ignored }; library.stepFilm(1); return .handled }
            .help("↑ / ↓ to switch films when the preview is focused. Scroll to pan when zoomed.")
    }
    private var filmstrip: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) { Caption(text: "SESSION"); Text(String(format: "%02d", library.photos.count)).font(.system(size: 22, weight: .light, design: .monospaced)) }.frame(width: 67)
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
        }.padding(.horizontal, 28).frame(height: 110)
    }
    private var footer: some View {
        HStack(spacing: 8) {
            if library.busy || library.exporting { ProgressView().controlSize(.mini).scaleEffect(0.7) } else { Circle().fill(Color.subtle).frame(width: 4, height: 4) }
            Text(library.status).font(.system(size: 10)).foregroundStyle(Color.subtle)
            Spacer()
            Caption(text: "NONDESTRUCTIVE  /  LOCAL  /  YOURS")
        }.padding(.horizontal, 24).frame(height: 32)
    }
}

struct ResetSettingsMenu: View {
    @EnvironmentObject var library: Library
    var body: some View {
        Menu {
            Button("Reset Adjustments · Keep Film") { library.reset(keepingFilm: true) }
            Button("Reset All Settings") { library.reset() }
        } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
        .disabled(!library.canEdit)
        .help("Reset this photograph’s settings · Undo with ⌘Z")
    }
}
