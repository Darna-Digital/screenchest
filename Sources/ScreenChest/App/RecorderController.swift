import AppKit
import AVFoundation
import Observation
import ScreenCaptureKit

@MainActor
@Observable
final class RecorderController {
    enum Phase: Equatable {
        case idle
        case countdown(Int)
        case recording(Date)
        case finishing
    }

    enum SourceKind: String, CaseIterable, Identifiable {
        case display = "Display"
        case window = "Window"
        case camera = "Camera"
        var id: String { rawValue }
    }

    static let countdownSeconds = 3
    static let frameRate = 60

    var phase: Phase = .idle
    var sourceKind: SourceKind = .display
    var displays: [CaptureTarget] = []
    var windows: [CaptureTarget] = []
    var selectedDisplayID: String?
    var selectedWindowID: String?
    var cameras: [AVCaptureDevice] = []
    var microphones: [AVCaptureDevice] = []
    var selectedCameraID: String?
    var selectedMicrophoneID: String?
    var cameraEnabled = false
    var microphoneEnabled = true
    var systemAudioEnabled = true
    var hasScreenAccess = Permissions.hasScreenRecordingAccess()
    var errorMessage: String?
    var finishedProjectURL: URL?
    var recentProjects: [URL] = []
    private(set) var session: RecordingSession?
    private(set) var previewCapture: DeviceCapture?

    @ObservationIgnored weak var cameraBubbleWindow: NSWindow?
    @ObservationIgnored private var ownApplications: [SCRunningApplication] = []
    @ObservationIgnored private var recordingTask: Task<Void, Never>?

    var selectedTarget: CaptureTarget? {
        switch sourceKind {
        case .display: displays.first { $0.id == selectedDisplayID }
        case .window: windows.first { $0.id == selectedWindowID }
        case .camera: nil
        }
    }

    var selectedCamera: AVCaptureDevice? { cameras.first { $0.uniqueID == selectedCameraID } }
    var selectedMicrophone: AVCaptureDevice? { microphones.first { $0.uniqueID == selectedMicrophoneID } }
    var isIdle: Bool { phase == .idle }
    var cameraBubbleSession: AVCaptureSession? {
        if let capture = session?.deviceCapture, capture.hasCamera { return capture.session }
        return previewCapture?.session
    }
    var isCameraOnly: Bool { sourceKind == .camera }
    var usesCamera: Bool { isCameraOnly || cameraEnabled }
    var canRecord: Bool {
        guard isIdle else { return false }
        return isCameraOnly ? selectedCamera != nil : hasScreenAccess && selectedTarget != nil
    }

    func refreshSources() async {
        hasScreenAccess = Permissions.hasScreenRecordingAccess()
        recentProjects = ProjectStore.listPackages()
        refreshDevices()
        guard hasScreenAccess else { return }
        do {
            let content = try await ShareableContent.load()
            displays = content.displays
            windows = content.windows
            ownApplications = content.ownApplications
            if !displays.contains(where: { $0.id == selectedDisplayID }) {
                selectedDisplayID = displays.first?.id
            }
            if !windows.contains(where: { $0.id == selectedWindowID }) {
                selectedWindowID = windows.first?.id
            }
        } catch {
            hasScreenAccess = Permissions.hasScreenRecordingAccess()
            if hasScreenAccess {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refreshDevices() {
        cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        microphones = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        if !cameras.contains(where: { $0.uniqueID == selectedCameraID }) {
            selectedCameraID = (AVCaptureDevice.default(for: .video) ?? cameras.first)?.uniqueID
        }
        if !microphones.contains(where: { $0.uniqueID == selectedMicrophoneID }) {
            selectedMicrophoneID = (AVCaptureDevice.default(for: .audio) ?? microphones.first)?.uniqueID
        }
    }

    func requestScreenAccess() {
        Permissions.requestScreenRecordingAccess()
        hasScreenAccess = Permissions.hasScreenRecordingAccess()
    }

    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    func setCameraEnabled(_ enabled: Bool) async {
        if enabled, !(await Permissions.ensureAccess(to: .video)) {
            cameraEnabled = false
            errorMessage = CaptureError.cameraNotAllowed.localizedDescription
            return
        }
        cameraEnabled = enabled
        refreshDevices()
        updatePreview()
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        if enabled, !(await Permissions.ensureAccess(to: .audio)) {
            microphoneEnabled = false
            errorMessage = CaptureError.microphoneNotAllowed.localizedDescription
            return
        }
        microphoneEnabled = enabled
        refreshDevices()
    }

    func sourceKindDidChange() async {
        if isCameraOnly, !(await Permissions.ensureAccess(to: .video)) {
            errorMessage = CaptureError.cameraNotAllowed.localizedDescription
        }
        updatePreview()
    }

    func updatePreview() {
        let wanted = isIdle && usesCamera ? selectedCamera : nil
        if let previewCapture, previewCapture.cameraID == wanted?.uniqueID { return }
        stopPreview()
        guard let wanted, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        previewCapture = try? DeviceCapture(camera: wanted, microphone: nil)
        previewCapture?.start()
    }

    func stopPreview() {
        guard let previewCapture else { return }
        self.previewCapture = nil
        Task { await previewCapture.stop() }
    }

    func startRecording() {
        guard canRecord else { return }
        errorMessage = nil
        let target = selectedTarget
        recordingTask = Task { await run(target: target) }
    }

    func cancelCountdown() {
        recordingTask?.cancel()
    }

    func stopRecording() {
        Task { await finish() }
    }

    private func run(target: CaptureTarget?) async {
        var microphone: AVCaptureDevice?
        if microphoneEnabled {
            if await Permissions.ensureAccess(to: .audio) {
                microphone = selectedMicrophone
                if microphone == nil { errorMessage = CaptureError.cannotUseMicrophone.localizedDescription }
            } else {
                microphoneEnabled = false
                errorMessage = CaptureError.microphoneNotAllowed.localizedDescription
            }
        }
        var camera: AVCaptureDevice?
        if usesCamera {
            if await Permissions.ensureAccess(to: .video) {
                camera = selectedCamera
                if camera == nil { errorMessage = CaptureError.cannotUseCamera.localizedDescription }
            } else {
                cameraEnabled = false
                errorMessage = CaptureError.cameraNotAllowed.localizedDescription
            }
        }
        if target == nil, camera == nil {
            return
        }
        let configuration = RecordingSession.Configuration(
            target: target,
            excludedApplications: ownApplications,
            camera: camera,
            microphone: microphone,
            capturesSystemAudio: systemAudioEnabled,
            frameRate: RecorderController.frameRate
        )
        let session: RecordingSession
        do {
            session = try RecordingSession(configuration: configuration, packageURL: ProjectStore.newPackageURL())
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        self.session = session
        if let previewCapture {
            self.previewCapture = nil
            await previewCapture.stop()
        }
        session.onStreamError = { [weak self] error in
            Task { @MainActor in self?.handleStreamError(error) }
        }
        session.prepare()
        do {
            for remaining in stride(from: RecorderController.countdownSeconds, through: 1, by: -1) {
                phase = .countdown(remaining)
                try await Task.sleep(for: .seconds(1))
            }
            try await session.start()
            phase = .recording(Date())
        } catch {
            await session.cancel()
            self.session = nil
            phase = .idle
            updatePreview()
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finish() async {
        guard case .recording = phase, let session else { return }
        phase = .finishing
        let cameraCorner = cameraCornerNearestBubble(for: session.configuration.target)
        do {
            _ = try await session.stop(cameraCorner: cameraCorner)
            finishedProjectURL = session.packageURL
        } catch {
            errorMessage = error.localizedDescription
        }
        self.session = nil
        recentProjects = ProjectStore.listPackages()
        phase = .idle
    }

    private func cameraCornerNearestBubble(for target: CaptureTarget?) -> CameraStyle.Corner {
        guard let target, let bubble = cameraBubbleWindow?.frame, let primaryScreen = NSScreen.screens.first else { return .bottomRight }
        let bubbleCenter = CGPoint(x: bubble.midX, y: primaryScreen.frame.height - bubble.midY)
        let area = target.currentFrame()
        let isLeft = bubbleCenter.x < area.midX
        let isTop = bubbleCenter.y < area.midY
        switch (isLeft, isTop) {
        case (true, true): return .topLeft
        case (false, true): return .topRight
        case (true, false): return .bottomLeft
        case (false, false): return .bottomRight
        }
    }

    private func handleStreamError(_ error: Error) {
        errorMessage = CaptureError.streamStopped(error.localizedDescription).localizedDescription
        if case .recording = phase {
            Task { await finish() }
        }
    }
}
