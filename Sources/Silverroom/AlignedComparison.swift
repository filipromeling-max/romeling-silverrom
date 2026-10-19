import AppKit
import SwiftUI

/// Two independent viewports showing the same image coordinates at the same scale.
struct AlignedComparison: NSViewRepresentable {
    let left: NSImage
    let right: NSImage
    let imageSize: CGSize
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> PairView {
        let view = PairView()
        context.coordinator.connect(view)
        return view
    }
    func updateNSView(_ view: PairView, context: Context) {
        context.coordinator.update(view, left: left, right: right, size: imageSize)
    }
    final class FlippedImage: NSImageView { override var isFlipped: Bool { true } }
    final class PairView: NSView {
        let scrolls = [NSScrollView(), NSScrollView()]
        override init(frame: NSRect) {
            super.init(frame: frame)
            for scroll in scrolls {
                scroll.hasHorizontalScroller = true; scroll.hasVerticalScroller = true
                scroll.autohidesScrollers = true; scroll.drawsBackground = true
                scroll.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 1)
                let image = FlippedImage(); image.imageScaling = .scaleAxesIndependently
                scroll.documentView = image; scroll.contentView.postsBoundsChangedNotifications = true
                addSubview(scroll)
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override func layout() {
            super.layout()
            let width = max(1, (bounds.width - 16) / 2)
            scrolls[0].frame = NSRect(x: 0, y: 0, width: width, height: bounds.height)
            scrolls[1].frame = NSRect(x: width + 16, y: 0, width: width, height: bounds.height)
        }
    }
    final class Coordinator {
        private var observers: [NSObjectProtocol] = []
        private var synchronizing = false
        func connect(_ view: PairView) {
            for (index, scroll) in view.scrolls.enumerated() {
                observers.append(NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak self, weak view] _ in
                    guard let self, let view, !self.synchronizing else { return }
                    self.synchronizing = true
                    self.move(view.scrolls[1 - index], to: scroll.contentView.bounds.origin)
                    self.synchronizing = false
                })
            }
        }
        func update(_ view: PairView, left: NSImage, right: NSImage, size: CGSize) {
            synchronizing = true
            defer { synchronizing = false }
            let oldSize = view.scrolls[0].documentView?.frame.size ?? .zero
            let oldBounds = view.scrolls[0].contentView.bounds
            for (index, scroll) in view.scrolls.enumerated() {
                guard let image = scroll.documentView as? NSImageView else { continue }
                image.image = index == 0 ? left : right
                image.frame.size = size
            }
            if oldSize != size && oldSize.width > 0 && oldSize.height > 0 {
                let point = CGPoint(x: oldBounds.midX / oldSize.width * size.width - oldBounds.width / 2,
                                    y: oldBounds.midY / oldSize.height * size.height - oldBounds.height / 2)
                for scroll in view.scrolls { move(scroll, to: point) }
            }
        }
        private func move(_ scroll: NSScrollView, to point: CGPoint) {
            let size = scroll.documentView?.frame.size ?? .zero
            scroll.contentView.scroll(to: CGPoint(x: max(0, min(size.width - scroll.contentView.bounds.width, point.x)),
                                                  y: max(0, min(size.height - scroll.contentView.bounds.height, point.y))))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
    }
}
