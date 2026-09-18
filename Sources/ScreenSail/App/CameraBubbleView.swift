import SwiftUI

struct CameraBubbleView: View {
    static let windowID = "camera-bubble"
    static let diameter: CGFloat = 220

    @Environment(RecorderController.self) private var recorder
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if let capture = recorder.session?.deviceCapture, capture.hasCamera {
                CameraPreview(session: capture.session)
            } else {
                Color.black
            }
        }
        .frame(width: CameraBubbleView.diameter, height: CameraBubbleView.diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .padding(20)
        .onAppear {
            if recorder.phase == .idle { dismissWindow(id: CameraBubbleView.windowID) }
        }
        .onChange(of: recorder.phase) { _, phase in
            if phase == .idle { dismissWindow(id: CameraBubbleView.windowID) }
        }
    }
}
