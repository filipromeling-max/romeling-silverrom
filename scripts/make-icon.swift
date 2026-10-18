import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let artworkURL = root.appendingPathComponent("Assets/RomelingSilverroom-Icon.png")
guard let artwork = NSImage(contentsOf: artworkURL) else { fatalError("Missing generated icon artwork") }
let directory = root.appendingPathComponent(".build/Romeling.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        // Apply the standard rounded tile silhouette when encoding native icon sizes.
        // The original generated artwork remains unchanged in Assets.
        let side = CGFloat(pixels)
        NSBezierPath(roundedRect: NSRect(x: side * 0.065, y: side * 0.065, width: side * 0.87, height: side * 0.87), xRadius: side * 0.18, yRadius: side * 0.18).addClip()
        NSGraphicsContext.current?.imageInterpolation = .high
        artwork.draw(in: NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels)), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
