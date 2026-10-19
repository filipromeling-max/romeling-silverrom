import AppKit
import CoreImage

// New stages are neutral by default so existing photographs retain their edits.
struct Development: Codable, Equatable {
    var response = 0.0
    var pushPull = 0.0
    var adaptiveGrain = 0.0
    var grainColor = 0.0
    var format = "35mm"
    var advancedHalation = 0.0
    var halationThreshold = 0.7
    var halationSpread = 0.35
    var halationHue = 0.035
    var scanner = "neutral"
    var scannerStrength = 1.0
    var scanContrast = 1.0
    var scanSharpness = 0.0
}
enum MaskKind: String, Codable, CaseIterable {
    case radial = "Radial", gradient = "Gradient", brush = "Brush", luminance = "Luminance", color = "Color range"
}
struct MaskPoint: Codable, Equatable { var x: Double; var y: Double }
struct MaskStroke: Codable, Equatable { var points: [MaskPoint]; var erase = false }
struct LocalMask: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "Local adjustment"
    var kind: MaskKind = .radial
    var enabled = true
    var inverted = false
    var x = 0.5
    var y = 0.5
    var radius = 0.3
    var feather = 0.5
    var angle = 90.0
    var threshold = 0.5
    var hue = 0.1
    var hueWidth = 0.15
    var strokes: [MaskStroke] = []
    var exposure = 0.0
    var warmth = 0.0
    var saturation = 1.0
    var contrast = 1.0
    var softness = 0.0
}

extension Engine {
    static func exposureResponse(_ input: CIImage, recipe r: Recipe) -> CIImage {
        let p = r.development.pushPull
        let strength = r.development.response
        var result = input
        if strength > 0 {
            // Reversal profiles reach their shoulder earlier than negative profiles.
            let reversal = r.film.kind == "COLOR REVERSAL"
            let over = max(0, r.exposure), under = max(0, -r.exposure)
            let shoulder = min(0.48, over * strength * (reversal ? 0.13 : 0.09))
            result = result.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0),
                "inputPoint1": CIVector(x: 0.25, y: 0.25 - under * strength * 0.025),
                "inputPoint2": CIVector(x: 0.5, y: 0.5 - shoulder * 0.14),
                "inputPoint3": CIVector(x: 0.75, y: 0.75 - shoulder * 0.5),
                "inputPoint4": CIVector(x: 1, y: 1 - shoulder)])
            result = result.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: max(0.5, 1 - over * strength * 0.08 + under * strength * 0.035)])
            if !r.film.monochrome {
                result = result.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1 + over * strength * 0.025, y: 0, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1 + under * strength * 0.035, w: 0)])
            }
        }
        if abs(p) > 0.001 {
            result = result.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1 + p * 0.085, kCIInputSaturationKey: max(0.5, 1 - abs(p) * 0.055)])
            result = result.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: max(0, -p) * 0.012),
                "inputPoint1": CIVector(x: 0.25, y: 0.25 - p * 0.022),
                "inputPoint2": CIVector(x: 0.5, y: 0.5),
                "inputPoint3": CIVector(x: 0.75, y: 0.75 + p * 0.012),
                "inputPoint4": CIVector(x: 1, y: 1 - max(0, -p) * 0.025)])
            if !r.film.monochrome {
                result = result.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500 + p * 100, y: p * 3), "inputTargetNeutral": CIVector(x: 6500, y: 0)])
            }
        }
        return result
    }
    static func threshold(_ image: CIImage, at value: Double) -> CIImage {
        let gain = 1 / max(0.02, 1 - value)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
            "inputBiasVector": CIVector(x: -value * gain, y: -value * gain, z: -value * gain, w: 0)])
            .applyingFilter("CIColorClamp")
    }
    static func advancedHalo(_ image: CIImage, base: CIImage, recipe r: Recipe, scale: Double) -> CIImage {
        let extent = image.extent
        let luminance = base.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        let highlights = threshold(luminance, at: r.development.halationThreshold)
        let edges = luminance.clampedToExtent().applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 3]).cropped(to: extent)
        let seed = highlights.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edges])
        let spread = (2 + r.development.halationSpread * 45) * scale
        let blurred = seed.clampedToExtent().applyingGaussianBlur(sigma: max(0.2, spread)).cropped(to: extent)
        let rgb = hueRGB(r.development.halationHue)
        let power = r.halation * r.development.advancedHalation * 0.7
        let glow = blurred.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: rgb.0 * power, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: rgb.1 * power, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: rgb.2 * power, w: 0)])
        return glow.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image]).cropped(to: extent)
    }
    static func filmGrain(_ image: CIImage, recipe r: Recipe, scale: Double) -> CIImage {
        let d = r.development
        let formatScale = d.format == "120" ? 0.55 : d.format == "110" ? 1.6 : 1
        let push = max(0.4, 1 + d.pushPull * 0.2)
        let amount = min(1, r.film.grain * max(0, r.grain) * 0.25 * push * formatScale)
        guard amount > 0 else { return image }
        let extent = image.extent
        let noise = CIFilter.randomGenerator().outputImage!
            .transformed(by: .init(scaleX: max(0.25, scale * r.grainSize * formatScale), y: max(0.25, scale * r.grainSize * formatScale)))
            .cropped(to: extent).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: r.film.monochrome ? 0 : d.grainColor])
            .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount)])
        let grained = noise.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        guard d.adaptiveGrain > 0 else { return grained }
        let mask = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter("CIColorPolynomial", parameters: [
                "inputRedCoefficients": CIVector(x: 0.9, y: 0.4, z: -1.1, w: 0),
                "inputGreenCoefficients": CIVector(x: 0.9, y: 0.4, z: -1.1, w: 0),
                "inputBlueCoefficients": CIVector(x: 0.9, y: 0.4, z: -1.1, w: 0)])
            .applyingFilter("CIColorClamp")
        let adaptive = grained.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask])
        return mix(adaptive, over: grained, amount: d.adaptiveGrain)
    }
    static func scan(_ input: CIImage, recipe r: Recipe, scale: Double) -> CIImage {
        let d = r.development
        if d.scanner == "neutral" && d.scanContrast == 1 && d.scanSharpness == 0 { return input }
        var scanned = input
        switch d.scanner {
        case "minilab":
            scanned = input.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.08, kCIInputSaturationKey: 1.08])
                .applyingFilter("CIColorMatrix", parameters: ["inputBiasVector": CIVector(x: 0.012, y: 0.004, z: -0.006, w: 0)])
        case "editorial":
            scanned = input.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.04, kCIInputSaturationKey: 0.9])
                .applyingFilter("CIColorMatrix", parameters: ["inputBVector": CIVector(x: 0, y: 0, z: 1.04, w: 0)])
        case "print":
            scanned = input.clampedToExtent().applyingGaussianBlur(sigma: max(0.15, scale * 0.8)).cropped(to: input.extent)
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 0.94, kCIInputSaturationKey: 0.95])
        default: break
        }
        if r.film.monochrome && r.amount >= 1 { scanned = scanned.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0]) }
        var result = d.scannerStrength <= 0 ? input : mix(scanned, over: input, amount: d.scannerStrength)
        if d.scanContrast != 1 { result = result.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: d.scanContrast]) }
        if d.scanSharpness > 0 {
            result = result.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: max(0.2, scale * 2), kCIInputIntensityKey: d.scanSharpness]).cropped(to: input.extent)
        }
        return result
    }
    static func localMask(_ m: LocalMask, image: CIImage) -> CIImage {
        let e = image.extent
        let center = CGPoint(x: e.minX + m.x * e.width, y: e.minY + (1 - m.y) * e.height)
        var mask: CIImage
        switch m.kind {
        case .radial:
            let radius = max(1, m.radius * e.width)
            mask = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter": CIVector(cgPoint: center), "inputRadius0": radius * (1 - m.feather), "inputRadius1": radius, "inputColor0": CIColor.white, "inputColor1": CIColor.black])!.outputImage!
        case .gradient:
            let angle = m.angle * .pi / 180, length = max(1, m.radius * e.width)
            let delta = CGPoint(x: cos(angle) * length / 2, y: sin(angle) * length / 2)
            mask = CIFilter(name: "CISmoothLinearGradient", parameters: ["inputPoint0": CIVector(x: center.x - delta.x, y: center.y - delta.y), "inputPoint1": CIVector(x: center.x + delta.x, y: center.y + delta.y), "inputColor0": CIColor.black, "inputColor1": CIColor.white])!.outputImage!
        case .brush:
            let width = min(1024, max(1, Int(e.width))), height = max(1, Int(Double(width) * e.height / e.width))
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.setFillColor(gray: 0, alpha: 1); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setLineCap(.round); context.setLineJoin(.round)
            for stroke in m.strokes where !stroke.points.isEmpty {
                let value: CGFloat = stroke.erase ? 0 : 1
                context.setStrokeColor(gray: value, alpha: 1); context.setFillColor(gray: value, alpha: 1)
                let diameter = m.radius * Double(width) * 2
                context.setLineWidth(diameter)
                if stroke.points.count == 1, let p = stroke.points.first {
                    context.fillEllipse(in: CGRect(x: p.x * Double(width) - diameter / 2, y: (1 - p.y) * Double(height) - diameter / 2, width: diameter, height: diameter))
                } else {
                    context.beginPath()
                    for (i, p) in stroke.points.enumerated() {
                        let point = CGPoint(x: p.x * Double(width), y: (1 - p.y) * Double(height))
                        if i == 0 { context.move(to: point) } else { context.addLine(to: point) }
                    }
                    context.strokePath()
                }
            }
            mask = CIImage(cgImage: context.makeImage()!).transformed(by: .init(scaleX: e.width / Double(width), y: e.height / Double(height)))
                .clampedToExtent().applyingGaussianBlur(sigma: m.feather * m.radius * e.width * 0.3)
        case .luminance:
            mask = threshold(image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0]), at: m.threshold)
        case .color:
            var cube: [Float] = []
            let dimension = 16
            for b in 0..<dimension { for g in 0..<dimension { for r in 0..<dimension {
                let color = NSColor(srgbRed: Double(r)/15, green: Double(g)/15, blue: Double(b)/15, alpha: 1).usingColorSpace(.deviceRGB)!
                let distance = abs(color.hueComponent - m.hue)
                let circular = min(distance, 1 - distance)
                let weight = max(0, 1 - circular / max(0.02, m.hueWidth)) * min(1, color.saturationComponent * 3)
                cube += [Float(weight), Float(weight), Float(weight), 1]
            } } }
            let data = cube.withUnsafeBufferPointer { Data(buffer: $0) }
            mask = image.applyingFilter("CIColorCubeWithColorSpace", parameters: ["inputCubeDimension": dimension, "inputCubeData": data, "inputColorSpace": colorSpace])
        }
        if m.inverted { mask = mask.applyingFilter("CIColorInvert") }
        return mask.cropped(to: e)
    }
    static func localDevelop(_ input: CIImage, masks: [LocalMask]) -> CIImage {
        // All range masks are evaluated against one stable pre-local image.
        var result = input
        for mask in masks where mask.enabled {
            var edited = result.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: mask.exposure])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: mask.saturation, kCIInputContrastKey: mask.contrast])
            if mask.warmth != 0 { edited = edited.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500 + mask.warmth * 2000, y: 0), "inputTargetNeutral": CIVector(x: 6500, y: 0)]) }
            if mask.softness > 0 { edited = edited.clampedToExtent().applyingGaussianBlur(sigma: mask.softness * input.extent.width * 0.008).cropped(to: input.extent) }
            result = edited.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: result, kCIInputMaskImageKey: localMask(mask, image: input)])
        }
        return result.cropped(to: input.extent)
    }
}
