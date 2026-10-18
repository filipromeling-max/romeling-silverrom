import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

struct Engine {
    static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!])
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    static let rawExtensions: Set<String> = ["dng", "cr2", "cr3", "nef", "nrw", "arw", "raf", "orf", "rw2", "pef", "3fr", "fff", "srw", "raw"]
    static func load(_ url: URL) throws -> CIImage {
        if rawExtensions.contains(url.pathExtension.lowercased()) {
            guard let filter = CIRAWFilter(imageURL: url), let image = filter.outputImage else {
                throw Failure.message("This RAW file could not be decoded. Camera support depends on the RAW formats supported by your version of macOS.")
            }
            return normalize(image)
        }
        guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { throw Failure.message("This file could not be opened as a photograph.") }
        return normalize(image)
    }
    static func normalize(_ image: CIImage) -> CIImage {
        image.transformed(by: .init(translationX: -image.extent.minX, y: -image.extent.minY))
    }
    static func scaled(_ image: CIImage, maxDimension: CGFloat) -> CIImage {
        let scale = min(1, maxDimension / max(image.extent.width, image.extent.height))
        return image.transformed(by: .init(scaleX: scale, y: scale))
    }
    static func develop(_ source: CIImage, recipe r: Recipe, originalWidth: CGFloat? = nil) -> CIImage {
        let f = r.film
        let extent = source.extent
        let scale = extent.width / (originalWidth ?? extent.width)
        var base = source.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: r.exposure])
        base = base.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500 + r.warmth * 2000, y: r.tint * 80), "inputTargetNeutral": CIVector(x: 6500, y: 0)])
        base = base.applyingFilter("CIHighlightShadowAdjust", parameters: ["inputHighlightAmount": 1 - r.highlights * 0.8, "inputShadowAmount": r.shadows])
        base = base.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: r.contrast, kCIInputSaturationKey: r.saturation])
        var film = base.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: f.saturation, kCIInputContrastKey: f.contrast])
        film = film.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1 + f.warmth * 0.18, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1 - f.tint * 0.2, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1 - f.warmth * 0.18, w: 0)])
        if f.id == "purple" { film = film.applyingFilter("CIColorCubeWithColorSpace", parameters: ["inputCubeDimension": 24, "inputCubeData": purpleCube, "inputColorSpace": colorSpace]) }
        film = film.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0, y: f.fade), "inputPoint1": CIVector(x: 0.25, y: 0.23 + f.fade),
            "inputPoint2": CIVector(x: 0.5, y: 0.51), "inputPoint3": CIVector(x: 0.75, y: 0.78), "inputPoint4": CIVector(x: 1, y: 0.98)])
        if f.halation * r.halation > 0 {
            let mask = base.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0.7, y: 0.7, z: 0.7, w: 0), "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)])
                .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 3.33, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 3.33, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 3.33, w: 0), "inputBiasVector": CIVector(x: -2.331, y: -2.331, z: -2.331, w: 0)])
            let glow = mask.clampedToExtent().applyingGaussianBlur(sigma: max(0.7, 15 * scale)).cropped(to: extent)
                .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: f.halation * r.halation * 0.32, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: f.halation * r.halation * 0.065, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
            film = glow.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: film]).cropped(to: extent)
        }
        if f.grain * r.grain > 0 {
            // Core Image's repeatable noise field is sampled in original pixel coordinates.
            let noise = CIFilter.randomGenerator().outputImage!.transformed(by: .init(scaleX: max(0.25, scale * r.grainSize), y: max(0.25, scale * r.grainSize))).cropped(to: extent)
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: f.grain * r.grain * 0.25)])
            film = noise.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: film])
        }
        let mask = CIImage(color: CIColor(red: r.amount, green: r.amount, blue: r.amount)).cropped(to: extent)
        var result = film.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: base, kCIInputMaskImageKey: mask])
        result = creative(result, recipe: r)
        if r.vignette > 0 { result = result.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: r.vignette, kCIInputRadiusKey: max(extent.width, extent.height) * 0.6]) }
        return result.cropped(to: extent)
    }
    // Creative finishing follows the emulsion blend, so film strength does not
    // silently disable independently authored light or color treatments.
    static func creative(_ input: CIImage, recipe r: Recipe) -> CIImage {
        let extent = input.extent
        var image = input
        if r.crossProcess > 0 {
            let shifted = image.applyingFilter("CIColorPolynomial", parameters: [
                "inputRedCoefficients": CIVector(x: 0.035, y: 0.82, z: 0.18, w: 0),
                "inputGreenCoefficients": CIVector(x: 0.015, y: 1.10, z: -0.12, w: 0),
                "inputBlueCoefficients": CIVector(x: 0.08, y: 0.74, z: 0.12, w: 0)])
            image = mix(shifted, over: image, amount: r.crossProcess)
        }
        if r.fade > 0 || r.blackPoint > 0 {
            image = image.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: r.fade * 0.15 - r.blackPoint * 0.09),
                "inputPoint1": CIVector(x: 0.25, y: 0.25 + r.fade * 0.06 - r.blackPoint * 0.06),
                "inputPoint2": CIVector(x: 0.5, y: 0.5),
                "inputPoint3": CIVector(x: 0.75, y: 0.75 - r.fade * 0.025),
                "inputPoint4": CIVector(x: 1, y: 1 - r.fade * 0.05)])
        }
        // Both masks come from the same luminance image, independent of hue choice.
        let luminance = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter("CIColorClamp")
        for (hue, amount, shadows) in [(r.shadowHue, r.shadowTone, true), (r.highlightHue, r.highlightTone, false)] where amount > 0 {
            let rgb = hueRGB(hue)
            let toned = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1 + (rgb.0 - 0.5) * amount * 0.7, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1 + (rgb.1 - 0.5) * amount * 0.7, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1 + (rgb.2 - 0.5) * amount * 0.7, w: 0)])
            let mask = shadows ? luminance.applyingFilter("CIColorInvert") : luminance
            image = toned.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask])
        }
        if r.bloom > 0 {
            image = image.clampedToExtent().applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: max(extent.width, extent.height) * (0.003 + r.bloomRadius * 0.025), kCIInputIntensityKey: r.bloom * 0.8]).cropped(to: extent)
        }
        if r.lightLeak > 0 {
            let rgb = hueRGB(r.leakHue)
            let leak = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": CIVector(x: extent.minX + r.leakX * extent.width, y: extent.minY + (1 - r.leakY) * extent.height),
                "inputRadius0": 0, "inputRadius1": max(extent.width, extent.height) * (0.15 + r.leakSize * 0.8),
                "inputColor0": CIColor(red: rgb.0 * r.lightLeak * 0.8, green: rgb.1 * r.lightLeak * 0.8, blue: rgb.2 * r.lightLeak * 0.8),
                "inputColor1": CIColor(red: 0, green: 0, blue: 0)])!.outputImage!.cropped(to: extent)
            image = leak.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        }
        return image.cropped(to: extent)
    }
    static func mix(_ foreground: CIImage, over background: CIImage, amount: Double) -> CIImage {
        let mask = CIImage(color: CIColor(red: amount, green: amount, blue: amount)).cropped(to: background.extent)
        return foreground.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: background, kCIInputMaskImageKey: mask])
    }
    static func hueRGB(_ hue: Double) -> (Double, Double, Double) {
        let h = (hue - floor(hue)) * 6
        let x = 1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)
        switch Int(h) {
        case 0: return (1, x, 0)
        case 1: return (x, 1, 0)
        case 2: return (0, 1, x)
        case 3: return (0, x, 1)
        case 4: return (x, 0, 1)
        default: return (1, 0, x)
        }
    }
    // Authored selective hue transform, not a measured manufacturer LUT.
    static let purpleCube: Data = {
        var values = [Float]()
        for b in 0..<24 { for g in 0..<24 { for r in 0..<24 {
            let red = Double(r) / 23, green = Double(g) / 23, blue = Double(b) / 23
            let dominance = max(0, green - max(red, blue))
            let shift = min(1, dominance * 2.5)
            values += [Float(red * (1 - shift) + green * 0.85 * shift), Float(green * (1 - shift) + red * 0.45 * shift), Float(blue * (1 - shift) + green * shift), 1]
        } } }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }()
    static func cgImage(_ image: CIImage) throws -> CGImage {
        guard let result = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace) else { throw Failure.message("The image could not be rendered.") }
        return result
    }
    static func export(_ image: CIImage, to url: URL, format: String) throws {
        switch format {
        case "tiff": try context.writeTIFFRepresentation(of: image, to: url, format: .RGBA16, colorSpace: colorSpace)
        case "png": try context.writePNGRepresentation(of: image, to: url, format: .RGBA8, colorSpace: colorSpace)
        default: try context.writeJPEGRepresentation(of: image, to: url, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95])
        }
    }
}
enum Failure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
