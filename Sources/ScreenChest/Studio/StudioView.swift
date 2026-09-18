import AppKit
import SwiftUI

struct StudioView: View {
    static let windowID = "studio"

    @Environment(StudioLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var model: EditorModel?
    @State private var loadError: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            StudioSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 480)
        } detail: {
            detail
                .navigationTitle(model?.project.name ?? "Studio")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openWindow(id: RecorderView.windowID)
                        } label: {
                            Label("New Recording", systemImage: "record.circle")
                        }
                        .help("New recording (⌘1)")
                    }
                }
        }
        .frame(minWidth: 960, minHeight: 600)
        .onAppear {
            library.refresh()
            dismissWindow(id: RecorderView.windowID)
        }
        .onDisappear { model?.close() }
        .onOpenURL { library.open($0) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.refresh()
        }
        .task(id: library.selection) {
            model?.close()
            model = nil
            loadError = nil
            guard let selection = library.selection else { return }
            do {
                let model = try EditorModel(packageURL: selection)
                self.model = model
                await model.load()
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let model {
            EditorView(model: model)
                .id(model.packageURL)
        } else if let loadError {
            ContentUnavailableView("Couldn't open recording", systemImage: "exclamationmark.triangle", description: Text(loadError))
        } else if library.selection != nil {
            ProgressView("Opening recording…")
        } else {
            ContentUnavailableView {
                Label("No Recording Open", systemImage: "film.stack")
            } description: {
                Text("Pick a recording from the sidebar, or start a new one.")
            } actions: {
                Button("New Recording") { openWindow(id: RecorderView.windowID) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct StudioSidebar: View {
    let model: EditorModel?
    @Environment(StudioLibrary.self) private var library
    @State private var recordingToTrash: LibraryRecording?

    var body: some View {
        @Bindable var library = library
        Form {
            Section {
                Picker("Video", selection: $library.selection) {
                    if library.recordings.isEmpty {
                        Text("No recordings yet").tag(URL?.none)
                    } else if library.selection == nil {
                        Text("Choose…").tag(URL?.none)
                    }
                    ForEach(library.groups) { group in
                        Section(group.period.title) {
                            ForEach(group.recordings) { recording in
                                Text("\(recording.name)  ·  \(TimeFormatting.clock(recording.duration))")
                                    .tag(Optional(recording.url))
                            }
                        }
                    }
                }
                if let current = library.current {
                    HStack {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([current.url])
                        }
                        Button("Move to Trash…", role: .destructive) {
                            recordingToTrash = current
                        }
                    }
                }
            }
            if let model {
                EditorControlSections(model: model)
                    .id(model.packageURL)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .confirmationDialog(
            "Move “\(recordingToTrash?.name ?? "")” to the Trash?",
            isPresented: Binding(get: { recordingToTrash != nil }, set: { if !$0 { recordingToTrash = nil } }),
            presenting: recordingToTrash
        ) { recording in
            Button("Move to Trash", role: .destructive) { library.moveToTrash(recording.url) }
        } message: { _ in
            Text("The recording and its edits will be moved to the Trash.")
        }
    }
}
