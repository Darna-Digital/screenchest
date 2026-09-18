import AppKit
import SwiftUI

struct CameraBubbleView: View {
    static let windowID = "camera-bubble"
    static let diameter: CGFloat = 220

    @Environment(RecorderController.self) private var recorder
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var window: NSWindow?

    var body: some View {
        Group {
            if let session = recorder.cameraBubbleSession {
                CameraPreview(session: session)
            } else {
                Color.black
            }
        }
        .frame(width: CameraBubbleView.diameter, height: CameraBubbleView.diameter)
        .clipShape(Circle())
        .overlay(WindowDragArea().clipShape(Circle()))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .padding(20)
        .background(WindowAccessor(onWindow: adopt))
        .onAppear { dismissIfUnused() }
        .onChange(of: recorder.cameraBubbleSession == nil) { dismissIfUnused() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)) { notification in
            guard let window, notification.object as? NSWindow === window else { return }
            CameraBubblePlacement.save(window.frame.origin)
        }
    }

    private func adopt(_ found: NSWindow) {
        guard window !== found else { return }
        window = found
        recorder.cameraBubbleWindow = found
        CameraBubblePlacement.restore(into: found)
    }

    private func dismissIfUnused() {
        if recorder.cameraBubbleSession == nil {
            dismissWindow(id: CameraBubbleView.windowID)
        }
    }
}

enum CameraBubblePlacement {
    static let defaultsKey = "cameraBubbleOrigin"

    static func save(_ origin: CGPoint) {
        UserDefaults.standard.set([origin.x, origin.y], forKey: defaultsKey)
    }

    static func restore(into window: NSWindow) {
        guard let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [Double], saved.count == 2 else { return }
        let frame = CGRect(origin: CGPoint(x: saved[0], y: saved[1]), size: window.frame.size)
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) else { return }
        window.setFrameOrigin(frame.origin)
    }
}
