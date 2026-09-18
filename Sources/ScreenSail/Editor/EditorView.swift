import SwiftUI

struct EditorView: View {
    let packageURL: URL

    @State private var model: EditorModel?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let model {
                EditorContent(model: model)
            } else if let loadError {
                ContentUnavailableView("Couldn't open recording", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ProgressView("Opening recording…")
            }
        }
        .navigationTitle(model?.project.name ?? packageURL.deletingPathExtension().lastPathComponent)
        .task(id: packageURL) {
            do {
                let model = try EditorModel(packageURL: packageURL)
                self.model = model
                await model.load()
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

private struct EditorContent: View {
    let model: EditorModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                playerArea
                transportBar
                EditorTimeline(model: model)
                    .frame(height: 74)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            InspectorView(model: model)
                .frame(width: 320)
        }
        .frame(minWidth: 1000, minHeight: 640)
        .focusedSceneValue(\.editorModel, model)
        .onDisappear { model.saveNow() }
    }

    @ViewBuilder
    private var playerArea: some View {
        ZStack {
            Color.black
            switch model.loadState {
            case .loading:
                ProgressView()
                    .controlSize(.large)
            case .ready:
                PlayerView(player: model.player)
            case .failed(let message):
                ContentUnavailableView("Playback unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private var transportBar: some View {
        HStack(spacing: 12) {
            Button {
                model.togglePlayback()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 24)
            }
            .buttonStyle(.bordered)
            .disabled(model.loadState != .ready)
            Text("\(TimeFormatting.precise(model.currentTime)) / \(TimeFormatting.precise(model.duration))")
                .font(.body.monospacedDigit())
            Spacer()
            Text("Trim \(TimeFormatting.precise(model.edits.trimStart)) – \(TimeFormatting.precise(model.edits.trimEnd))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("Space to play · Z adds a zoom · ⌫ deletes")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}
