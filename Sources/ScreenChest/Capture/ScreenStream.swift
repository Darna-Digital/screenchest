import CoreMedia
import ScreenCaptureKit

final class ScreenStream: NSObject, SCStreamOutput, SCStreamDelegate {
    typealias VideoHandler = (CMSampleBuffer, SCFrameStatus) -> Void
    typealias AudioHandler = (CMSampleBuffer) -> Void
    typealias ErrorHandler = (Error) -> Void

    private var stream: SCStream!
    private let onVideo: VideoHandler
    private let onAudio: AudioHandler
    private let onError: ErrorHandler
    private let videoQueue = DispatchQueue(label: "screenchest.stream.video", qos: .userInteractive)
    private let audioQueue = DispatchQueue(label: "screenchest.stream.audio", qos: .userInteractive)

    init(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration,
        capturesAudio: Bool,
        onVideo: @escaping VideoHandler,
        onAudio: @escaping AudioHandler,
        onError: @escaping ErrorHandler
    ) throws {
        self.onVideo = onVideo
        self.onAudio = onAudio
        self.onError = onError
        super.init()
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        if capturesAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        }
    }

    func start() async throws {
        try await stream.startCapture()
    }

    func stop() async throws {
        try await stream.stopCapture()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer) else { return }
        switch type {
        case .screen:
            guard let status = ScreenStream.frameStatus(of: sampleBuffer) else { return }
            onVideo(sampleBuffer, status)
        case .audio:
            onAudio(sampleBuffer)
        default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onError(error)
    }

    private static func frameStatus(of sampleBuffer: CMSampleBuffer) -> SCFrameStatus? {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int else { return nil }
        return SCFrameStatus(rawValue: rawStatus)
    }
}
