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
        Form {
            Section {
                LabeledContent("Video") {
                    RecordingPicker()
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

private struct RecordingPicker: View {
    @Environment(StudioLibrary.self) private var library
    @State private var isPresented = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        Button {
            query = ""
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(library.current?.name ?? (library.recordings.isEmpty ? "No recordings yet" : "Choose…"))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(library.current == nil ? .secondary : .primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(library.recordings.isEmpty)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(spacing: 0) {
            TextField("Search recordings", text: $query)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                .focused($searchFocused)
                .onSubmit(chooseFirstMatch)
                .padding(10)
            Divider()
            if groups.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                List {
                    ForEach(groups) { group in
                        Section(group.period.title) {
                            ForEach(group.recordings) { recording in
                                Button {
                                    choose(recording)
                                } label: {
                                    HStack {
                                        Text(recording.name)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(TimeFormatting.clock(recording.duration))
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                        if recording == library.current {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: 340, height: 360)
        .onAppear { searchFocused = true }
    }

    private var groups: [LibraryGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return library.groups }
        return library.groups.compactMap { group in
            let matches = group.recordings.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            return matches.isEmpty ? nil : LibraryGroup(period: group.period, recordings: matches)
        }
    }

    private func chooseFirstMatch() {
        guard let first = groups.first?.recordings.first else { return }
        choose(first)
    }

    private func choose(_ recording: LibraryRecording) {
        library.selection = recording.url
        isPresented = false
    }
}
