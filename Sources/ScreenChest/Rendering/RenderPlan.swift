import CoreGraphics
import Foundation

struct StaticLayerKey: Hashable {
    let canvasWidth: Int
    let canvasHeight: Int
    let contentRect: [Double]
    let cornerRadius: Double
    let shadow: Bool
    let backgroundPresetID: String
    let cameraRect: [Double]?
    let cameraShape: CameraStyle.Shape?
}

struct RenderPlan {
    static let previewMaxHeight = 1440
    static let cameraMinimumMarginFraction = 0.025
    static let cameraRoundedRadiusFraction = 0.22

    let canvasSize: CGSize
    let sourceSize: CGSize
    let cornerRadius: CGFloat
    let shadow: Bool
    let background: BackgroundPreset
    let camera: CameraStyle
    let contentRect: CGRect
    let cameraRect: CGRect?
    let zoomTrack: ZoomTrack

    var canvasRect: CGRect { CGRect(origin: .zero, size: canvasSize) }

    var staticLayerKey: StaticLayerKey {
        StaticLayerKey(
            canvasWidth: Int(canvasSize.width),
            canvasHeight: Int(canvasSize.height),
            contentRect: [contentRect.minX, contentRect.minY, contentRect.width, contentRect.height],
            cornerRadius: cornerRadius,
            shadow: shadow,
            backgroundPresetID: background.id,
            cameraRect: cameraRect.map { [$0.minX, $0.minY, $0.width, $0.height] },
            cameraShape: cameraRect == nil ? nil : camera.shape
        )
    }

    var cameraCornerRadius: CGFloat {
        guard let cameraRect else { return 0 }
        return camera.shape == .circle ? cameraRect.width / 2 : cameraRect.width * RenderPlan.cameraRoundedRadiusFraction
    }

    static func make(project: Project, mouse: MouseTrack, canvasSize: CGSize, hasCamera: Bool) -> RenderPlan {
        let edits = project.edits
        let background = BackgroundPreset.named(edits.backgroundPresetID)
        let source = project.recording.pixelSize
        let minimumDimension = min(canvasSize.width, canvasSize.height)
        let padding = background.isNone ? 0 : minimumDimension * edits.padding
        let available = CGSize(width: max(1, canvasSize.width - padding * 2), height: max(1, canvasSize.height - padding * 2))
        let fit = background.isNone
            ? max(available.width / source.width, available.height / source.height)
            : min(available.width / source.width, available.height / source.height)
        let contentSize = CGSize(width: source.width * fit, height: source.height * fit)
        let contentRect = CGRect(
            x: (canvasSize.width - contentSize.width) / 2,
            y: (canvasSize.height - contentSize.height) / 2,
            width: contentSize.width,
            height: contentSize.height
        )

        var cameraRect: CGRect?
        if hasCamera, edits.camera.enabled {
            let diameter = canvasSize.height * edits.camera.size
            let margin = max(padding, canvasSize.height * cameraMinimumMarginFraction)
            let x = edits.camera.corner == .topLeft || edits.camera.corner == .bottomLeft ? margin : canvasSize.width - margin - diameter
            let y = edits.camera.corner == .bottomLeft || edits.camera.corner == .bottomRight ? margin : canvasSize.height - margin - diameter
            cameraRect = CGRect(x: x, y: y, width: diameter, height: diameter)
        }

        return RenderPlan(
            canvasSize: canvasSize,
            sourceSize: source,
            cornerRadius: background.isNone ? 0 : minimumDimension * edits.cornerRadius,
            shadow: edits.shadow && !background.isNone,
            background: background,
            camera: edits.camera,
            contentRect: contentRect,
            cameraRect: cameraRect,
            zoomTrack: ZoomTrackBuilder.build(segments: edits.zooms, mouse: mouse, duration: project.recording.duration)
        )
    }

    static func canvasSize(for source: CGSize, resolution: OutputResolution) -> CGSize {
        guard let maxHeight = resolution.maxHeight, source.height > CGFloat(maxHeight) else {
            return CaptureTarget.evenSize(source)
        }
        let scale = CGFloat(maxHeight) / source.height
        return CaptureTarget.evenSize(CGSize(width: source.width * scale, height: CGFloat(maxHeight)))
    }

    static func previewCanvasSize(for source: CGSize) -> CGSize {
        guard source.height > CGFloat(previewMaxHeight) else { return CaptureTarget.evenSize(source) }
        let scale = CGFloat(previewMaxHeight) / source.height
        return CaptureTarget.evenSize(CGSize(width: source.width * scale, height: CGFloat(previewMaxHeight)))
    }
}
