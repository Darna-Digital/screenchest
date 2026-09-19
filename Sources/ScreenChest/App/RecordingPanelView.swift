import SwiftUI

struct RecordingPanelView: View {
    static let windowID = "recording-panel"

    @Environment(RecorderController.self) private var recorder
    @Environment(StudioLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minWidth: 280)
        .floatingPanel()
        .movesWindowOnDrag()
        .padding(FloatingPanel.windowPadding)
        .environment(\.colorScheme, .dark)
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
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: remaining)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.12), in: Circle())
            Text("Starting…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            SubtlePanelButton(title: "Cancel") { recorder.cancelCountdown() }
                .keyboardShortcut(.cancelAction)
        case .recording(let start):
            RecordingIndicator()
            TimelineView(.periodic(from: start, by: 1)) { context in
                Text(TimeFormatting.clock(context.date.timeIntervalSince(start)))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 16)
            ProminentPanelButton(title: "Stop", systemImage: "stop.fill") { recorder.stopRecording() }
                .keyboardShortcut(.cancelAction)
                .help("Stop recording (Esc)")
        case .finishing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 40, height: 40)
            Text("Saving recording…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)
                .frame(height: 44)
        case .idle:
            Text("Ready")
                .foregroundStyle(.secondary)
                .frame(height: 44)
        }
    }

    private func leave() {
        if let url = recorder.finishedProjectURL {
            recorder.finishedProjectURL = nil
            library.open(url)
            openWindow(id: StudioView.windowID)
        } else {
            openWindow(id: RecorderView.windowID)
        }
        dismissWindow(id: RecordingPanelView.windowID)
    }
}

private struct RecordingIndicator: View {
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 12, height: 12)
            .shadow(color: .red.opacity(0.7), radius: 5)
            .opacity(dimmed ? 0.35 : 1)
            .frame(width: 40, height: 40)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dimmed = true }
            }
    }
}
