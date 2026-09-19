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
                .navigationTitle(model?.name ?? "Studio")
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

    var body: some View {
        VStack(spacing: 0) {
            RecordingPicker(model: model)
                .padding(.horizontal, 14)
                .padding(.top, 8)
            Form {
                if let model {
                    EditorControlSections(model: model)
                        .id(model.packageURL)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}
