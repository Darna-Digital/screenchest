import Foundation

enum CaptureError: LocalizedError {
    case screenRecordingNotAllowed
    case cameraNotAllowed
    case microphoneNotAllowed
    case cannotUseCamera
    case cannotUseMicrophone
    case writerSetupFailed
    case writerFailed
    case noFramesCaptured
    case streamStopped(String)

    var errorDescription: String? {
        switch self {
        case .screenRecordingNotAllowed:
            "Screen Recording permission is required. Enable ScreenSail in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch."
        case .cameraNotAllowed:
            "Camera access was denied. Enable it in System Settings → Privacy & Security → Camera."
        case .microphoneNotAllowed:
            "Microphone access was denied. Enable it in System Settings → Privacy & Security → Microphone."
        case .cannotUseCamera:
            "The selected camera could not be used."
        case .cannotUseMicrophone:
            "The selected microphone could not be used."
        case .writerSetupFailed:
            "The recording file could not be prepared."
        case .writerFailed:
            "Writing the recording failed."
        case .noFramesCaptured:
            "No frames were captured. Nothing was saved."
        case .streamStopped(let reason):
            "Screen capture stopped: \(reason)"
        }
    }
}
