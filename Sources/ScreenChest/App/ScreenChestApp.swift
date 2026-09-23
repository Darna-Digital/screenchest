import SwiftUI

@main
struct ScreenChestApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var recorder = RecorderController()
    @State private var library = StudioLibrary()

    var body: some Scene {
        Window("ScreenChest", id: RecorderView.windowID) {
            RecorderView()
                .environment(recorder)
                .environment(library)
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
                .environment(library)
        }
        .windowStyle(.plain)
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

        Window("Studio", id: StudioView.windowID) {
            StudioView()
                .environment(library)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .handlesExternalEvents(matching: [ProjectStore.packageExtension])
        .defaultSize(width: 1280, height: 840)
        .commands {
            EditorCommands()
        }
    }
}
