import AVFoundation
import ScreenCaptureKit

final class RecordingSession: @unchecked Sendable {
    struct Configuration {
        var target: CaptureTarget?
        var excludedApplications: [SCRunningApplication]
        var camera: AVCaptureDevice?
        var microphone: AVCaptureDevice?
        var capturesSystemAudio: Bool
        var frameRate: Int

        var isCameraOnly: Bool { target == nil }
    }

    static let cameraFrameRate = 30
    static let screenBitsPerPixel = 0.08
    static let cameraBitsPerPixel = 0.25

    let configuration: Configuration
    let packageURL: URL
    let deviceCapture: DeviceCapture?
    var onStreamError: ((Error) -> Void)?

    private let queue = DispatchQueue(label: "screenchest.recording", qos: .userInitiated)
    private let audioSettings: [[String: Any]]
    private let audioTracks: [AudioTrackKind]
    private let mouseTracker: MouseTracker?
    private var screenWriter: MediaWriter?
    private var pixelSize: CGSize
    private var stream: ScreenStream?
    private var cameraWriter: MediaWriter?
    private var cameraWriterFailed = false
    private var acceptsCameraOnlyFrames = false
    private var startTime: CMTime?
    private var failure: Error?

    init(configuration: Configuration, packageURL: URL) throws {
        self.configuration = configuration
        self.packageURL = packageURL
        if configuration.isCameraOnly, configuration.camera == nil {
            throw CaptureError.cannotUseCamera
        }
        try ProjectStore.createPackage(at: packageURL)

        if configuration.camera != nil || configuration.microphone != nil {
            deviceCapture = try DeviceCapture(camera: configuration.camera, microphone: configuration.microphone)
        } else {
            deviceCapture = nil
        }

        var tracks: [AudioTrackKind] = []
        var settings: [[String: Any]] = []
        if let microphoneSettings = deviceCapture?.microphoneWriterSettings {
            tracks.append(.microphone)
            settings.append(microphoneSettings)
        }
        if configuration.capturesSystemAudio, !configuration.isCameraOnly {
            tracks.append(.systemAudio)
            settings.append(AudioSettings.aac(channels: 2, sampleRate: 48_000, bitRate: 160_000))
        }
        audioTracks = tracks
        audioSettings = settings

        if let target = configuration.target {
            pixelSize = target.pixelSize
            screenWriter = try MediaWriter(
                url: packageURL.appendingPathComponent(ProjectStore.screenFileName),
                video: VideoSpec(size: pixelSize, frameRate: configuration.frameRate, bitsPerPixel: RecordingSession.screenBitsPerPixel),
                audio: settings
            )
            mouseTracker = MouseTracker(frameProvider: { target.currentFrame() })
        } else {
            pixelSize = .zero
            screenWriter = nil
            mouseTracker = nil
        }

        deviceCapture?.onVideo = { [weak self] in self?.handleCameraFrame($0) }
        deviceCapture?.onAudio = { [weak self] in self?.handleMicrophoneAudio($0) }
    }

    func prepare() {
        deviceCapture?.start()
    }

    func start() async throws {
        guard let target = configuration.target else {
            queue.async { self.acceptsCameraOnlyFrames = true }
            return
        }
        let filter = target.makeContentFilter(excluding: configuration.excludedApplications)
        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.width = Int(pixelSize.width)
        streamConfiguration.height = Int(pixelSize.height)
        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfiguration.colorSpaceName = CGColorSpace.sRGB
        streamConfiguration.showsCursor = true
        streamConfiguration.queueDepth = 6
        streamConfiguration.shouldBeOpaque = true
        streamConfiguration.capturesAudio = configuration.capturesSystemAudio
        streamConfiguration.sampleRate = 48_000
        streamConfiguration.channelCount = 2
        streamConfiguration.excludesCurrentProcessAudio = true

        let stream = try ScreenStream(
            filter: filter,
            configuration: streamConfiguration,
            capturesAudio: configuration.capturesSystemAudio,
            onVideo: { [weak self] in self?.handleScreenFrame($0, status: $1) },
            onAudio: { [weak self] in self?.handleSystemAudio($0) },
            onError: { [weak self] in self?.onStreamError?($0) }
        )
        self.stream = stream
        mouseTracker?.start()
        try await stream.start()
    }

    func stop(cameraCorner: CameraStyle.Corner = .bottomRight) async throws -> Project {
        let stopTime = CMClockGetTime(CMClockGetHostTimeClock())
        if let stream {
            try? await stream.stop()
        }
        await deviceCapture?.stop()
        mouseTracker?.stop()

        let (startTime, screenWriter, cameraWriter, pixelSize, failure) = await withCheckedContinuation { continuation in
            queue.async {
                self.acceptsCameraOnlyFrames = false
                self.screenWriter?.finishInputs(at: stopTime)
                self.cameraWriter?.finishInputs(at: stopTime)
                continuation.resume(returning: (self.startTime, self.screenWriter, self.cameraWriter, self.pixelSize, self.failure))
            }
        }

        if let failure {
            discardPackage()
            throw failure
        }
        guard let startTime, let screenWriter else {
            discardPackage()
            throw CaptureError.noFramesCaptured
        }
        do {
            try await screenWriter.finishWriting()
        } catch {
            discardPackage()
            throw error
        }

        var cameraFile: String?
        if let cameraWriter {
            do {
                try await cameraWriter.finishWriting()
                cameraFile = ProjectStore.cameraFileName
            } catch {
                try? FileManager.default.removeItem(at: cameraWriter.url)
            }
        }

        let duration = max(0, CMTimeSubtract(stopTime, startTime).seconds)
        let mouse = mouseTracker?.track(startingAt: startTime.seconds) ?? .empty
        try ProjectStore.saveMouseTrack(mouse, to: packageURL)
        let zooms = AutoZoom.generate(from: mouse, duration: duration)
        let project = Project(
            name: packageURL.deletingPathExtension().lastPathComponent,
            createdAt: Date(),
            recording: RecordingInfo(
                screenFile: ProjectStore.screenFileName,
                cameraFile: cameraFile,
                mouseFile: ProjectStore.mouseFileName,
                audioTracks: audioTracks,
                pixelWidth: Int(pixelSize.width),
                pixelHeight: Int(pixelSize.height),
                duration: duration,
                sourceName: configuration.target?.title ?? configuration.camera?.localizedName ?? "Camera"
            ),
            edits: .initial(duration: duration, zooms: zooms, hasCamera: cameraFile != nil, cameraCorner: cameraCorner)
        )
        try ProjectStore.save(project, to: packageURL)
        return project
    }

    func cancel() async {
        if let stream {
            try? await stream.stop()
        }
        await deviceCapture?.stop()
        mouseTracker?.stop()
        await withCheckedContinuation { continuation in
            queue.async {
                self.acceptsCameraOnlyFrames = false
                self.screenWriter?.cancel()
                self.cameraWriter?.cancel()
                continuation.resume()
            }
        }
        discardPackage()
    }

    private func discardPackage() {
        try? FileManager.default.removeItem(at: packageURL)
    }

    private func handleScreenFrame(_ sampleBuffer: CMSampleBuffer, status: SCFrameStatus) {
        guard status == .complete || status == .started,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        queue.async {
            guard let screenWriter = self.screenWriter else { return }
            if self.startTime == nil {
                do {
                    try screenWriter.start(at: time)
                } catch {
                    self.fail(with: error)
                    return
                }
                self.startTime = time
                self.startCameraWriterIfPossible()
            }
            screenWriter.appendVideo(pixelBuffer, at: time)
        }
    }

    private func handleCameraFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        queue.async {
            if self.configuration.isCameraOnly {
                self.appendCameraOnlyFrame(pixelBuffer, size: size, at: time)
                return
            }
            if self.cameraWriter == nil, !self.cameraWriterFailed, self.failure == nil {
                self.cameraWriter = try? MediaWriter(
                    url: self.packageURL.appendingPathComponent(ProjectStore.cameraFileName),
                    video: VideoSpec(size: size, frameRate: RecordingSession.cameraFrameRate, bitsPerPixel: RecordingSession.cameraBitsPerPixel),
                    audio: []
                )
                self.cameraWriterFailed = self.cameraWriter == nil
                self.startCameraWriterIfPossible()
            }
            guard let startTime = self.startTime, time >= startTime else { return }
            self.cameraWriter?.appendVideo(pixelBuffer, at: time)
        }
    }

    private func appendCameraOnlyFrame(_ pixelBuffer: CVPixelBuffer, size: CGSize, at time: CMTime) {
        guard acceptsCameraOnlyFrames, failure == nil else { return }
        if screenWriter == nil {
            do {
                let writer = try MediaWriter(
                    url: packageURL.appendingPathComponent(ProjectStore.screenFileName),
                    video: VideoSpec(size: size, frameRate: RecordingSession.cameraFrameRate, bitsPerPixel: RecordingSession.cameraBitsPerPixel),
                    audio: audioSettings
                )
                try writer.start(at: time)
                screenWriter = writer
                pixelSize = CaptureTarget.evenSize(size)
                startTime = time
            } catch {
                fail(with: error)
                return
            }
        }
        screenWriter?.appendVideo(pixelBuffer, at: time)
    }

    private func handleMicrophoneAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let track = audioTracks.firstIndex(of: .microphone) else { return }
        queue.async { self.screenWriter?.appendAudio(sampleBuffer, track: track) }
    }

    private func handleSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let track = audioTracks.firstIndex(of: .systemAudio) else { return }
        queue.async { self.screenWriter?.appendAudio(sampleBuffer, track: track) }
    }

    private func startCameraWriterIfPossible() {
        guard let startTime, let cameraWriter, !cameraWriter.isStarted else { return }
        do {
            try cameraWriter.start(at: startTime)
        } catch {
            cameraWriter.cancel()
            self.cameraWriter = nil
            cameraWriterFailed = true
        }
    }

    private func fail(with error: Error) {
        guard failure == nil else { return }
        failure = error
        onStreamError?(error)
    }
}
