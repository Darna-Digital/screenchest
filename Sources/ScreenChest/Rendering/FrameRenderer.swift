import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Metal

final class FrameRenderer {
    static let shadowBlurFraction: CGFloat = 0.03
    static let shadowOffsetFraction: CGFloat = 0.012
    static let shadowOpacity: CGFloat = 0.55

    private static let sharedContext: CIContext = {
        let options: [CIContextOption: Any] = [.cacheIntermediates: false]
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: options)
        }
        return CIContext(options: options)
    }()

    private let context = FrameRenderer.sharedContext
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var cachedStaticKey: StaticLayerKey?
    private var cachedStaticLayer: CIImage?

    func render(screen: CVPixelBuffer?, camera: CVPixelBuffer?, time: Double, plan: RenderPlan, into output: CVPixelBuffer) {
        var image = staticLayer(for: plan)
        if let screen {
            image = screenLayer(screen, time: time, plan: plan).composited(over: image)
        }
        if let camera, let cameraRect = plan.cameraRect {
            image = cameraLayer(camera, in: cameraRect, plan: plan).composited(over: image)
        }
        context.render(image, to: output, bounds: plan.canvasRect, colorSpace: colorSpace)
    }

    private func staticLayer(for plan: RenderPlan) -> CIImage {
        let key = plan.staticLayerKey
        if let cachedStaticLayer, cachedStaticKey == key { return cachedStaticLayer }

        var image = backgroundLayer(for: plan)
        if plan.shadow {
            image = shadow(for: plan.contentRect, cornerRadius: plan.cornerRadius, plan: plan).composited(over: image)
            if let cameraRect = plan.cameraRect {
                image = shadow(for: cameraRect, cornerRadius: plan.cameraCornerRadius, plan: plan).composited(over: image)
            }
        }
        let layer = image.cropped(to: plan.canvasRect)
        cachedStaticKey = key
        cachedStaticLayer = layer
        return layer
    }

    private func backgroundLayer(for plan: RenderPlan) -> CIImage {
        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: 0, y: plan.canvasSize.height)
        gradient.point1 = CGPoint(x: plan.canvasSize.width, y: 0)
        gradient.color0 = color(plan.background.top)
        gradient.color1 = color(plan.background.bottom)
        return (gradient.outputImage ?? CIImage(color: color(plan.background.bottom))).cropped(to: plan.canvasRect)
    }

    private func shadow(for rect: CGRect, cornerRadius: CGFloat, plan: RenderPlan) -> CIImage {
        let offset = plan.canvasSize.height * FrameRenderer.shadowOffsetFraction
        let shape = roundedRectangle(
            rect.offsetBy(dx: 0, dy: -offset),
            radius: cornerRadius,
            color: CIColor(red: 0, green: 0, blue: 0, alpha: FrameRenderer.shadowOpacity, colorSpace: colorSpace) ?? .black
        )
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = shape
        blur.radius = Float(plan.canvasSize.height * FrameRenderer.shadowBlurFraction)
        return (blur.outputImage ?? shape).cropped(to: plan.canvasRect)
    }

    private func screenLayer(_ pixelBuffer: CVPixelBuffer, time: Double, plan: RenderPlan) -> CIImage {
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        let sourceWidth = source.extent.width
        let sourceHeight = source.extent.height
        let zoom = plan.zoomTrack.state(at: time)
        let cropWidth = sourceWidth / zoom.scale
        let cropHeight = sourceHeight / zoom.scale
        let cropX = zoom.cx * sourceWidth - cropWidth / 2
        let cropY = sourceHeight - (zoom.cy * sourceHeight + cropHeight / 2)
        let scale = plan.contentRect.width / cropWidth

        let scaled = lanczosScaled(source, by: scale)
        let placed = scaled
            .transformed(by: CGAffineTransform(translationX: plan.contentRect.minX - cropX * scale, y: plan.contentRect.minY - cropY * scale))
            .cropped(to: plan.contentRect)
        return masked(placed, to: plan.contentRect, radius: plan.cornerRadius)
    }

    private func cameraLayer(_ pixelBuffer: CVPixelBuffer, in rect: CGRect, plan: RenderPlan) -> CIImage {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let width = image.extent.width
        let height = image.extent.height
        if plan.camera.mirrored {
            image = image.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0))
        }
        let scale = rect.width / min(width, height)
        image = lanczosScaled(image, by: scale)
        let scaledWidth = width * scale
        let scaledHeight = height * scale
        image = image
            .transformed(by: CGAffineTransform(translationX: rect.minX - (scaledWidth - rect.width) / 2, y: rect.minY - (scaledHeight - rect.height) / 2))
            .cropped(to: rect)
        return masked(image, to: rect, radius: plan.cameraCornerRadius)
    }

    private func lanczosScaled(_ image: CIImage, by scale: CGFloat) -> CIImage {
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(scale)
        filter.aspectRatio = 1
        return filter.outputImage ?? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private func masked(_ image: CIImage, to rect: CGRect, radius: CGFloat) -> CIImage {
        guard radius > 0 else { return image }
        let mask = roundedRectangle(rect, radius: radius, color: .white)
        return image.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: mask])
    }

    private func roundedRectangle(_ rect: CGRect, radius: CGFloat, color: CIColor) -> CIImage {
        let generator = CIFilter.roundedRectangleGenerator()
        generator.extent = rect
        generator.radius = Float(min(radius, min(rect.width, rect.height) / 2))
        generator.color = color
        return (generator.outputImage ?? CIImage(color: color)).cropped(to: rect)
    }

    private func color(_ rgb: RGB) -> CIColor {
        CIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1, colorSpace: colorSpace)
            ?? CIColor(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
