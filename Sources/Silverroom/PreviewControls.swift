import SwiftUI

enum ComparisonMode: String, CaseIterable {
    case developed = "Developed"
    case original = "Original"
    case vertical = "Vertical split"
    case horizontal = "Horizontal split"
    case sideBySide = "Side by side"
    var isSplit: Bool { self == .vertical || self == .horizontal }
}

struct PreviewControls: View {
    @EnvironmentObject var library: Library
    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Comparison", selection: $library.comparisonMode) {
                    ForEach(ComparisonMode.allCases, id: \.self) { Text($0 == .original && library.comparisonVersionID != nil ? "Reference only" : $0.rawValue).tag($0) }
                }.pickerStyle(.inline)
                Divider()
                Menu("Compare against") {
                    Button("Original photograph") { library.comparisonVersionID = nil }
                    ForEach(library.selected?.versions ?? []) { version in
                        Button(version.name) { library.comparisonVersionID = version.id; if library.comparisonMode == .developed { library.comparisonMode = .sideBySide } }
                    }
                }
            } label: { Label(library.comparisonMode == .developed ? "Compare" : (library.comparisonMode == .original && library.comparisonVersionID != nil ? "Reference only" : library.comparisonMode.rawValue), systemImage: "rectangle.lefthalf.inset.filled") }
                .menuStyle(.borderlessButton).fixedSize().help("Choose a comparison view. B toggles original / developed.")
            if library.comparisonMode.isSplit {
                Slider(value: $library.splitPosition, in: 0...1).frame(width: 70).accessibilityLabel("Comparison divider position")
                    .help("Move the divider, or drag it on the photograph")
            }
            HStack(spacing: 8) {
                Button { library.stepZoom(-1) } label: { Image(systemName: "minus").frame(width: 24, height: 24) }
                    .disabled(library.zoomLevel == 0.25).help("Zoom out · ⌘−").accessibilityLabel("Zoom out")
                Menu {
                    Button("Fit to window") { library.zoomLevel = 0 }
                    Divider()
                    ForEach(Library.zoomSteps, id: \.self) { level in
                        Button("\(Int(level * 100))%") { library.zoomLevel = level }
                    }
                } label: { Text(library.zoomLevel == 0 ? "Fit" : "\(Int(library.zoomLevel * 100))%").monospacedDigit().frame(minWidth: 42) }
                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Zoom level")
                Button { library.stepZoom(1) } label: { Image(systemName: "plus").frame(width: 24, height: 24) }
                    .disabled(library.zoomLevel == 4).help("Zoom in · ⌘=").accessibilityLabel("Zoom in")
            }.buttonStyle(.borderless)
        }.font(.system(size: 12)).disabled(!library.canEdit)
    }
}

struct ImageComparison: View {
    @EnvironmentObject var library: Library
    let image: NSImage
    let size: CGSize
    var body: some View {
        Group {
            if library.comparisonVersionID != nil && library.versionPreview == nil {
                Image(nsImage: image).resizable().frame(width: size.width, height: size.height)
                    .overlay { Text("Preparing comparison…").padding(10).background(.black.opacity(0.75)) }
            } else if library.comparisonMode == .sideBySide, let original = library.comparisonImage {
                HStack(spacing: 16) {
                    labeled(original, title: library.referenceName.uppercased())
                    labeled(image, title: "DEVELOPED")
                }
            } else {
                ZStack(alignment: .topLeading) {
                    Image(nsImage: library.comparisonMode == .original ? (library.comparisonImage ?? image) : image)
                        .resizable().frame(width: size.width, height: size.height)
                    if library.comparisonMode.isSplit, let original = library.comparisonImage {
                        let vertical = library.comparisonMode == .vertical
                        Image(nsImage: original).resizable().frame(width: size.width, height: size.height)
                            .mask(alignment: .topLeading) {
                                Rectangle().frame(width: vertical ? size.width * library.splitPosition : size.width,
                                                  height: vertical ? size.height : size.height * library.splitPosition)
                            }
                        Rectangle().fill(.white.opacity(0.9))
                            .frame(width: vertical ? 1 : size.width, height: vertical ? size.height : 1)
                            .position(x: vertical ? size.width * library.splitPosition : size.width / 2,
                                      y: vertical ? size.height / 2 : size.height * library.splitPosition)
                        Image(systemName: vertical ? "arrow.left.and.right" : "arrow.up.and.down")
                            .font(.system(size: 12, weight: .semibold)).padding(10).background(.black.opacity(0.75), in: Circle())
                            .position(x: vertical ? size.width * library.splitPosition : size.width / 2,
                                      y: vertical ? size.height / 2 : size.height * library.splitPosition)
                        Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            library.splitPosition = min(1, max(0, vertical ? value.location.x / size.width : value.location.y / size.height))
                        }).accessibilityHidden(true)
                        VStack { HStack { badge(library.referenceName.uppercased()); Spacer(); if vertical { badge("DEVELOPED") } }; Spacer(); if !vertical { HStack { Spacer(); badge("DEVELOPED") } } }.padding(8).allowsHitTesting(false)
                    } else if library.comparisonMode == .original {
                        badge(library.referenceName.uppercased()).padding(8)
                    }
                    if library.showMask && library.comparisonMode == .developed, let mask = library.maskPreview {
                        Rectangle().fill(.red.opacity(0.35)).frame(width: size.width, height: size.height)
                            .mask { Image(nsImage: mask).resizable().luminanceToAlpha() }.allowsHitTesting(false)
                    }
                    if library.comparisonMode == .developed && !library.zoom && !library.editingMask && !library.placingLight {
                        if library.directAdjustment { ImageAdjustmentSurface(size: size) }
                        else if library.activeTool == .texture && library.loupeVisible { TextureTarget(size: size) }
                    }
                    if library.placingLight && library.canEdit { LightPlacement(size: size) }
                    if library.editingMask && library.canEdit { MaskPlacement(size: size) }
                }.frame(width: size.width, height: size.height).clipped()
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(library.comparisonMode.rawValue + " photograph")
    }
    private func badge(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).tracking(1).padding(6).lineLimit(1).background(.black.opacity(0.7))
    }
    private func labeled(_ image: NSImage, title: String) -> some View {
        Image(nsImage: image).resizable().frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) { badge(title).padding(8) }
    }
}
