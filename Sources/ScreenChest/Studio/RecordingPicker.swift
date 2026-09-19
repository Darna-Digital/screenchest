import AppKit
import SwiftUI

struct RecordingPicker: View {
    let model: EditorModel?
    @Environment(StudioLibrary.self) private var library
    @State private var thumbnails = RecordingThumbnails()
    @State private var isPresented = false
    @State private var renameOnOpen: URL?
    @State private var recordingToTrash: LibraryRecording?

    var body: some View {
        HStack(spacing: 4) {
            Button {
                open()
            } label: {
                header
            }
            .buttonStyle(HoverHighlightButtonStyle())
            .disabled(library.recordings.isEmpty)
            .help("Switch recording")
            if let current = library.current {
                RecordingActionsMenu(recording: current, rename: { open(renaming: current.url) }, trash: { recordingToTrash = current })
                    .buttonStyle(HoverHighlightButtonStyle())
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            RecordingList(
                model: model,
                thumbnails: thumbnails,
                initialRename: renameOnOpen,
                isPresented: $isPresented,
                recordingToTrash: $recordingToTrash
            )
        }
        .confirmationDialog(
            "Move “\(recordingToTrash?.name ?? "")” to the Trash?",
            isPresented: Binding(get: { recordingToTrash != nil }, set: { if !$0 { recordingToTrash = nil } }),
            presenting: recordingToTrash
        ) { recording in
            Button("Move to Trash", role: .destructive) { library.moveToTrash(recording.url) }
        } message: { _ in
            Text("The recording and its edits will be moved to the Trash.")
        }
        .onChange(of: library.current) { _, current in
            if let current { thumbnails.load(current) }
        }
        .onAppear {
            if let current = library.current { thumbnails.load(current) }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            RecordingThumbnail(image: library.current.flatMap(thumbnails.image(for:)), width: 44)
            VStack(alignment: .leading, spacing: 2) {
                if let current = library.current {
                    Text(current.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("\(current.createdAt.formatted(.relative(presentation: .named))) · \(TimeFormatting.clock(current.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No recordings yet")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Your recordings will show up here.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }

    private func open(renaming url: URL? = nil) {
        renameOnOpen = url
        isPresented = true
    }
}

private struct RecordingActionsMenu: View {
    let recording: LibraryRecording
    let rename: () -> Void
    let trash: () -> Void

    var body: some View {
        Menu {
            Button("Rename…", action: rename)
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([recording.url]) }
            Divider()
            Button("Move to Trash…", role: .destructive, action: trash)
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Recording actions")
    }
}

private struct HoverHighlightButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(configuration.isPressed ? 0.12 : isHovering ? 0.06 : 0))
            )
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private enum PickerField: Hashable {
    case search
    case rename
}

private struct RecordingList: View {
    static let width: CGFloat = 380
    static let maxListHeight: CGFloat = 420

    let model: EditorModel?
    let thumbnails: RecordingThumbnails
    let initialRename: URL?
    @Binding var isPresented: Bool
    @Binding var recordingToTrash: LibraryRecording?

    @Environment(StudioLibrary.self) private var library
    @State private var query = ""
    @State private var highlighted: URL?
    @State private var editing: URL?
    @State private var draftName = ""
    @State private var renameError: String?
    @FocusState private var focus: PickerField?

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(10)
            Divider()
            if groups.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: Self.width)
        .onAppear {
            highlighted = library.selection
            if let initialRename, let recording = library.recording(at: initialRename) {
                beginRename(recording)
            } else {
                focus = .search
            }
        }
        .onChange(of: query) {
            highlighted = visibleRecordings.first?.url
        }
        .onChange(of: focus) { previous, current in
            if previous == .rename, current != .rename, editing != nil {
                commitRename()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search recordings", text: $query)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)
                .onSubmit(chooseHighlighted)
                .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
                .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
                .onKeyPress(.escape) { isPresented = false; return .handled }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text(query.isEmpty ? "No recordings yet" : "No matches")
                .foregroundStyle(.secondary)
            if !query.isEmpty {
                Text("Nothing named “\(query.trimmingCharacters(in: .whitespaces))”.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(groups) { group in
                        Text(group.period.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, group.id == groups.first?.id ? 4 : 10)
                            .padding(.bottom, 3)
                        ForEach(group.recordings) { recording in
                            row(recording)
                                .id(recording.url)
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: Self.maxListHeight)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: highlighted) { _, url in
                if let url { proxy.scrollTo(url) }
            }
        }
    }

    private func row(_ recording: LibraryRecording) -> some View {
        RecordingRow(
            recording: recording,
            image: thumbnails.image(for:),
            isCurrent: recording.url == library.selection,
            isHighlighted: highlighted == recording.url && editing == nil,
            isEditing: editing == recording.url,
            draftName: $draftName,
            renameError: editing == recording.url ? renameError : nil,
            focus: $focus,
            choose: { choose(recording) },
            hover: { hovering in
                if editing == nil {
                    highlighted = hovering ? recording.url : (highlighted == recording.url ? nil : highlighted)
                }
            },
            commitRename: commitRename,
            cancelRename: cancelRename
        )
        .task { thumbnails.load(recording) }
        .contextMenu {
            Button("Rename") { beginRename(recording) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([recording.url]) }
            Divider()
            Button("Move to Trash…", role: .destructive) {
                isPresented = false
                recordingToTrash = recording
            }
        }
    }

    private var groups: [LibraryGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return library.groups }
        return library.groups.compactMap { group in
            let matches = group.recordings.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            return matches.isEmpty ? nil : LibraryGroup(period: group.period, recordings: matches)
        }
    }

    private var visibleRecordings: [LibraryRecording] {
        groups.flatMap(\.recordings)
    }

    private func moveHighlight(by offset: Int) {
        let visible = visibleRecordings
        guard !visible.isEmpty else { return }
        let index = visible.firstIndex { $0.url == highlighted } ?? (offset > 0 ? -1 : visible.count)
        let next = min(max(index + offset, 0), visible.count - 1)
        highlighted = visible[next].url
    }

    private func chooseHighlighted() {
        guard let recording = visibleRecordings.first(where: { $0.url == highlighted }) ?? visibleRecordings.first else { return }
        choose(recording)
    }

    private func choose(_ recording: LibraryRecording) {
        library.selection = recording.url
        isPresented = false
    }

    private func beginRename(_ recording: LibraryRecording) {
        editing = recording.url
        draftName = recording.name
        renameError = nil
        highlighted = recording.url
        focus = .rename
    }

    private func commitRename() {
        guard let url = editing else { return }
        if model?.packageURL == url { model?.saveNow() }
        do {
            highlighted = try library.rename(url, to: draftName)
            editing = nil
            renameError = nil
            focus = .search
        } catch {
            renameError = error.localizedDescription
            focus = .rename
        }
    }

    private func cancelRename() {
        editing = nil
        renameError = nil
        focus = .search
    }
}

private struct RecordingRow: View {
    let recording: LibraryRecording
    let image: (LibraryRecording) -> CGImage?
    let isCurrent: Bool
    let isHighlighted: Bool
    let isEditing: Bool
    @Binding var draftName: String
    let renameError: String?
    var focus: FocusState<PickerField?>.Binding
    let choose: () -> Void
    let hover: (Bool) -> Void
    let commitRename: () -> Void
    let cancelRename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 12)
                    .opacity(isCurrent ? 1 : 0)
                RecordingThumbnail(image: image(recording), width: 36)
                if isEditing {
                    TextField("Name", text: $draftName)
                        .textFieldStyle(.plain)
                        .focused(focus, equals: .rename)
                        .onSubmit(commitRename)
                        .onKeyPress(.escape) { cancelRename(); return .handled }
                } else {
                    Text(recording.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Text(TimeFormatting.clock(recording.duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(isHighlighted ? .white.opacity(0.85) : .secondary)
            }
            if let renameError {
                Text(renameError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 56)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(isHighlighted ? .white : .primary)
        .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing { choose() }
        }
        .onHover(perform: hover)
    }

    private var background: AnyShapeStyle {
        if isHighlighted { return AnyShapeStyle(Color.accentColor) }
        if isEditing { return AnyShapeStyle(.quaternary.opacity(0.6)) }
        return AnyShapeStyle(.clear)
    }
}
