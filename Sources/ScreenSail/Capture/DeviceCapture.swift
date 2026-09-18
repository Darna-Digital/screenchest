import AVFoundation

final class DeviceCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    typealias SampleHandler = (CMSampleBuffer) -> Void

    let session = AVCaptureSession()
    let hasCamera: Bool
    let hasMicrophone: Bool
    var onVideo: SampleHandler?
    var onAudio: SampleHandler?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let sampleQueue = DispatchQueue(label: "screensail.devices.samples", qos: .userInteractive)
    private let controlQueue = DispatchQueue(label: "screensail.devices.control", qos: .userInitiated)

    init(camera: AVCaptureDevice?, microphone: AVCaptureDevice?) throws {
        hasCamera = camera != nil
        hasMicrophone = microphone != nil
        super.init()

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let camera {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else { throw CaptureError.cannotUseCamera }
            session.addInput(input)
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
            guard session.canAddOutput(videoOutput) else { throw CaptureError.cannotUseCamera }
            session.addOutput(videoOutput)
            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            } else {
                session.sessionPreset = .high
            }
        }

        if let microphone {
            let input = try AVCaptureDeviceInput(device: microphone)
            guard session.canAddInput(input) else { throw CaptureError.cannotUseMicrophone }
            session.addInput(input)
            audioOutput.setSampleBufferDelegate(self, queue: sampleQueue)
            guard session.canAddOutput(audioOutput) else { throw CaptureError.cannotUseMicrophone }
            session.addOutput(audioOutput)
        }
    }

    var microphoneWriterSettings: [String: Any]? {
        guard hasMicrophone else { return nil }
        return audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
    }

    func start() {
        controlQueue.async { self.session.startRunning() }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            controlQueue.async {
                self.session.stopRunning()
                continuation.resume()
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let retimed = retimedToHostClock(sampleBuffer) else { return }
        if output === videoOutput {
            onVideo?(retimed)
        } else if output === audioOutput {
            onAudio?(retimed)
        }
    }

    private func retimedToHostClock(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        let hostClock = CMClockGetHostTimeClock()
        guard let sourceClock = session.synchronizationClock, !CFEqual(sourceClock, hostClock) else { return sampleBuffer }

        var count: CMItemCount = 0
        guard CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr,
              count > 0 else { return sampleBuffer }
        var timings = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        guard CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: &timings, entriesNeededOut: nil) == noErr else {
            return nil
        }
        for index in timings.indices {
            timings[index].presentationTimeStamp = CMSyncConvertTime(timings[index].presentationTimeStamp, from: sourceClock, to: hostClock)
            if timings[index].decodeTimeStamp.isValid {
                timings[index].decodeTimeStamp = CMSyncConvertTime(timings[index].decodeTimeStamp, from: sourceClock, to: hostClock)
            }
        }
        var retimed: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: count,
            sampleTimingArray: &timings,
            sampleBufferOut: &retimed
        )
        return status == noErr ? retimed : nil
    }
}
