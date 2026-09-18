import CoreGraphics
import Foundation
import ImageIO

enum BackgroundPainter {
    static let fallbackColor = RGB(hex: 0x1C1C1E)

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    static func render(_ preset: BackgroundPreset, size: CGSize) -> CGImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        switch preset.fill {
        case .none:
            context.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0, 0, 1]) ?? .black)
            context.fill(rect)
        case .gradient(let gradient):
            draw(gradient, in: context, rect: rect)
        case .image(let url):
            if let image = loadImage(at: url, covering: rect.size) {
                drawAspectFill(image, in: context, rect: rect)
            } else {
                context.setFillColor(cgColor(fallbackColor))
                context.fill(rect)
            }
        }
        return context.makeImage()
    }

    private static func draw(_ gradient: BackgroundPreset.Gradient, in context: CGContext, rect: CGRect) {
        let stops = gradient.stops.isEmpty ? [fallbackColor] : gradient.stops
        let locations = stops.indices.map { CGFloat($0) / CGFloat(max(1, stops.count - 1)) }
        if let linear = CGGradient(colorsSpace: colorSpace, colors: stops.map { cgColor($0) } as CFArray, locations: locations) {
            let (start, end) = axis(angle: gradient.angle, in: rect)
            context.drawLinearGradient(linear, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            context.setFillColor(cgColor(stops[0]))
            context.fill(rect)
        }
        context.setBlendMode(.screen)
        for glow in gradient.glows {
            let center = CGPoint(x: rect.minX + glow.center.x * rect.width, y: rect.maxY - glow.center.y * rect.height)
            let radius = glow.radius * max(rect.width, rect.height)
            let colors = [cgColor(glow.color, alpha: glow.opacity), cgColor(glow.color, alpha: 0)] as CFArray
            guard let radial = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { continue }
            context.drawRadialGradient(radial, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
        context.setBlendMode(.normal)
    }

    private static func axis(angle degrees: Double, in rect: CGRect) -> (start: CGPoint, end: CGPoint) {
        let radians = degrees * .pi / 180
        let direction = CGPoint(x: sin(radians), y: -cos(radians))
        let halfLength = (abs(direction.x) * rect.width + abs(direction.y) * rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return (
            CGPoint(x: center.x - direction.x * halfLength, y: center.y - direction.y * halfLength),
            CGPoint(x: center.x + direction.x * halfLength, y: center.y + direction.y * halfLength)
        )
    }

    private static func loadImage(at url: URL, covering size: CGSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let maxPixelSize = Int((max(size.width, size.height) * 1.5).rounded(.up))
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func drawAspectFill(_ image: CGImage, in context: CGContext, rect: CGRect) {
        let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let drawSize = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        context.interpolationQuality = .high
        context.draw(image, in: drawRect)
    }

    private static func cgColor(_ rgb: RGB, alpha: Double = 1) -> CGColor {
        CGColor(colorSpace: colorSpace, components: [rgb.r, rgb.g, rgb.b, alpha]) ?? CGColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha)
    }
}
