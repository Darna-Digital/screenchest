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
            } else if let preview = recorder.previewCapture {
                CameraPreview(session: preview.session)
            } else {
                Color.black
            }
        }
        .frame(width: CameraBubbleView.diameter, height: CameraBubbleView.diameter)
        .clipShape(Circle())
        .overlay(WindowDragArea().clipShape(Circle()))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .padding(20)
        .onAppear { dismissIfUnused() }
        .onChange(of: recorder.phase) { dismissIfUnused() }
        .onChange(of: recorder.previewCapture == nil) { dismissIfUnused() }
    }

    private func dismissIfUnused() {
        if recorder.phase == .idle, recorder.previewCapture == nil {
            dismissWindow(id: CameraBubbleView.windowID)
        }
    }
}
