import SwiftUI

@main
struct ScreenSailApp: App {
    @State private var recorder = RecorderController()

    var body: some Scene {
        Window("ScreenSail", id: RecorderView.windowID) {
            RecorderView()
                .environment(recorder)
        }
        .windowStyle(.plain)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { content, _ in
            WindowPlacement(.bottom, size: content.sizeThatFits(.unspecified))
        }
        .commands {
            RecorderCommands()
        }

        Window("Recording", id: RecordingPanelView.windowID) {
            RecordingPanelView()
                .environment(recorder)
        }
        .windowStyle(.hiddenTitleBar)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { content, _ in
            WindowPlacement(.top, size: content.sizeThatFits(.unspecified))
        }

        Window("Camera", id: CameraBubbleView.windowID) {
            CameraBubbleView()
                .environment(recorder)
        }
        .windowStyle(.plain)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { content, _ in
            WindowPlacement(.bottomLeading, size: content.sizeThatFits(.unspecified))
        }

        WindowGroup("Editor", for: URL.self) { $packageURL in
            if let packageURL {
                EditorView(packageURL: packageURL)
            }
        }
        .defaultSize(width: 1280, height: 840)
        .commands {
            EditorCommands()
        }
    }
}
