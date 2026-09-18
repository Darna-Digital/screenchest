import SwiftUI

struct EditorModelKey: FocusedValueKey {
    typealias Value = EditorModel
}

extension FocusedValues {
    var editorModel: EditorModel? {
        get { self[EditorModelKey.self] }
        set { self[EditorModelKey.self] = newValue }
    }
}

struct EditorCommands: Commands {
    @FocusedValue(\.editorModel) private var model

    var body: some Commands {
        CommandMenu("Playback") {
            Button(model?.isPlaying == true ? "Pause" : "Play") { model?.togglePlayback() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(model == nil)
            Button("Go to Start") { model?.seek(to: model?.edits.trimStart ?? 0) }
                .keyboardShortcut(.home, modifiers: [])
                .disabled(model == nil)
        }
        CommandMenu("Zoom") {
            Button("Add Zoom at Playhead") { model?.addZoomAtPlayhead() }
                .keyboardShortcut("z", modifiers: [])
                .disabled(model == nil)
            Button("Delete Selected Zoom") { model?.deleteSelectedZoom() }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(model?.selectedZoom == nil)
            Divider()
            Button("Regenerate Auto Zooms") { model?.regenerateZooms() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(model == nil)
        }
    }
}
