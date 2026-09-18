import AVFoundation
import CoreVideo

final class SailCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let plan: RenderPlan
    let screenTrackID: CMPersistentTrackID
    let cameraTrackID: CMPersistentTrackID?

    init(timeRange: CMTimeRange, plan: RenderPlan, screenTrackID: CMPersistentTrackID, cameraTrackID: CMPersistentTrackID?) {
        self.timeRange = timeRange
        self.plan = plan
        self.screenTrackID = screenTrackID
        self.cameraTrackID = cameraTrackID
        var ids: [NSValue] = [NSNumber(value: screenTrackID)]
        if let cameraTrackID {
            ids.append(NSNumber(value: cameraTrackID))
        }
        requiredSourceTrackIDs = ids
        super.init()
    }
}

enum CompositorError: Error {
    case unexpectedInstruction
    case noOutputBuffer
}

final class SailVideoCompositor: NSObject, AVVideoCompositing {
    private let renderer = FrameRenderer()
    private let renderQueue = DispatchQueue(label: "screenchest.compositor", qos: .userInteractive)
    private let pixelBufferAttributes: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
        kCVPixelBufferMetalCompatibilityKey as String: true,
    ]

    var sourcePixelBufferAttributes: [String: any Sendable]? { pixelBufferAttributes }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { pixelBufferAttributes }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func cancelAllPendingVideoCompositionRequests() {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async {
            guard let instruction = request.videoCompositionInstruction as? SailCompositionInstruction else {
                request.finish(with: CompositorError.unexpectedInstruction)
                return
            }
            guard let output = request.renderContext.newPixelBuffer() else {
                request.finish(with: CompositorError.noOutputBuffer)
                return
            }
            let screen = request.sourceFrame(byTrackID: instruction.screenTrackID)
            let camera = instruction.cameraTrackID.flatMap { request.sourceFrame(byTrackID: $0) }
            self.renderer.render(
                screen: screen,
                camera: camera,
                time: request.compositionTime.seconds,
                plan: instruction.plan,
                into: output
            )
            request.finish(withComposedVideoFrame: output)
        }
    }
}
