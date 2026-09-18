import SwiftUI

struct RecorderCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Show Recorder") { openWindow(id: RecorderView.windowID) }
                .keyboardShortcut("1", modifiers: .command)
        }
    }
}
