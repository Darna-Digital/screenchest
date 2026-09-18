import AVFoundation
import VideoToolbox

struct VideoSpec {
    let size: CGSize
    let frameRate: Int
    let bitsPerPixel: Double
}

enum AudioSettings {
    static func aac(channels: Int, sampleRate: Double, bitRate: Int) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitRate,
        ]
    }
}

final class MediaWriter {
    static let minimumBitRate = 6_000_000
    static let maximumBitRate = 90_000_000
    static let finalFrameReadinessAttempts = 50

    let url: URL
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput?
    private let videoAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let audioInputs: [AVAssetWriterInput]
    private var sessionStart: CMTime?
    private var lastVideoTime: CMTime?
    private var lastVideoFrame: CVPixelBuffer?
    private(set) var isFinished = false

    var isStarted: Bool { sessionStart != nil }

    init(url: URL, video: VideoSpec?, audio: [[String: Any]]) throws {
        self.url = url
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.movieFragmentInterval = CMTime(seconds: 5, preferredTimescale: 600)

        if let video {
            let size = CaptureTarget.evenSize(video.size)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: MediaWriter.bitRate(for: video),
                    AVVideoExpectedSourceFrameRateKey: video.frameRate,
                    AVVideoMaxKeyFrameIntervalKey: video.frameRate,
                    AVVideoAllowFrameReorderingKey: false,
                    AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel as String,
                ],
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw CaptureError.writerSetupFailed }
            writer.add(input)
            videoInput = input
            videoAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        } else {
            videoInput = nil
            videoAdaptor = nil
        }

        var inputs: [AVAssetWriterInput] = []
        for settings in audio {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw CaptureError.writerSetupFailed }
            writer.add(input)
            inputs.append(input)
        }
        audioInputs = inputs
    }

    func start(at time: CMTime) throws {
        guard sessionStart == nil else { return }
        guard writer.startWriting() else { throw writer.error ?? CaptureError.writerSetupFailed }
        writer.startSession(atSourceTime: time)
        sessionStart = time
    }

    func appendVideo(_ pixelBuffer: CVPixelBuffer, at time: CMTime) {
        guard !isFinished, isStarted, writer.status == .writing,
              let videoInput, let videoAdaptor else { return }
        if let lastVideoTime, time <= lastVideoTime { return }
        guard videoInput.isReadyForMoreMediaData else { return }
        if videoAdaptor.append(pixelBuffer, withPresentationTime: time) {
            lastVideoTime = time
            lastVideoFrame = pixelBuffer
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer, track: Int) {
        guard !isFinished, let sessionStart, writer.status == .writing, track < audioInputs.count else { return }
        let input = audioInputs[track]
        guard CMSampleBufferGetPresentationTimeStamp(sampleBuffer) >= sessionStart, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    func finishInputs(at endTime: CMTime) {
        guard !isFinished else { return }
        isFinished = true
        guard isStarted, writer.status == .writing else { return }
        holdLastFrame(until: endTime)
        writer.endSession(atSourceTime: endTime)
        videoInput?.markAsFinished()
        audioInputs.forEach { $0.markAsFinished() }
    }

    func finishWriting() async throws {
        guard isStarted else {
            try? FileManager.default.removeItem(at: url)
            throw CaptureError.noFramesCaptured
        }
        if writer.status == .writing {
            await writer.finishWriting()
        }
        guard writer.status == .completed else {
            throw writer.error ?? CaptureError.writerFailed
        }
    }

    func cancel() {
        isFinished = true
        if writer.status == .writing {
            writer.cancelWriting()
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func holdLastFrame(until endTime: CMTime) {
        guard let videoInput, let videoAdaptor, let frame = lastVideoFrame, let lastVideoTime, endTime > lastVideoTime else { return }
        var attempts = 0
        while !videoInput.isReadyForMoreMediaData, attempts < MediaWriter.finalFrameReadinessAttempts {
            Thread.sleep(forTimeInterval: 0.01)
            attempts += 1
        }
        guard videoInput.isReadyForMoreMediaData else { return }
        videoAdaptor.append(frame, withPresentationTime: endTime)
    }

    private static func bitRate(for video: VideoSpec) -> Int {
        let pixelsPerSecond = video.size.width * video.size.height * CGFloat(video.frameRate)
        let bitRate = Int(pixelsPerSecond * video.bitsPerPixel)
        return min(max(bitRate, minimumBitRate), maximumBitRate)
    }
}
