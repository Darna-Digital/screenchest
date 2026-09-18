import SwiftUI

struct RecordingPanelView: View {
    static let windowID = "recording-panel"

    @Environment(RecorderController.self) private var recorder
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(spacing: 14) {
            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minWidth: 300)
        .background(.ultraThinMaterial)
        .movesWindowOnDrag()
        .onAppear {
            if recorder.phase == .idle { leave() }
        }
        .onChange(of: recorder.phase) { _, phase in
            if phase == .idle { leave() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch recorder.phase {
        case .countdown(let remaining):
            Text("\(remaining)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 36)
            Text("Starting…")
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Cancel") { recorder.cancelCountdown() }
                .keyboardShortcut(.cancelAction)
        case .recording(let start):
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
            TimelineView(.periodic(from: start, by: 1)) { context in
                Text(TimeFormatting.clock(context.date.timeIntervalSince(start)))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            Button {
                recorder.stopRecording()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut(.cancelAction)
        case .finishing:
            ProgressView()
                .controlSize(.small)
            Text("Saving recording…")
                .foregroundStyle(.secondary)
        case .idle:
            Text("Ready")
                .foregroundStyle(.secondary)
        }
    }

    private func leave() {
        if let url = recorder.finishedProjectURL {
            recorder.finishedProjectURL = nil
            openWindow(value: url)
        }
        openWindow(id: RecorderView.windowID)
        dismissWindow(id: RecordingPanelView.windowID)
    }
}
