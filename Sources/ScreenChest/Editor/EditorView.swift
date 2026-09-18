import SwiftUI

struct EditorView: View {
    let model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            playerArea
            transportBar
            EditorTimeline(model: model)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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
            Text("\(TimeFormatting.precise(model.trimmedCurrentTime)) / \(TimeFormatting.precise(model.trimmedDuration))")
                .font(.body.monospacedDigit())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}
