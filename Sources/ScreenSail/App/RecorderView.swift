import AppKit
import SwiftUI

struct RecorderView: View {
    static let windowID = "recorder"

    @Environment(RecorderController.self) private var recorder
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        @Bindable var recorder = recorder
        VStack(alignment: .leading, spacing: 18) {
            header
            sourceSection(recorder: $recorder)
            if !recorder.hasScreenAccess, !recorder.isCameraOnly {
                permissionCard
            }
            devicesSection(recorder: $recorder)
            if recorder.usesCamera, let preview = recorder.previewCapture {
                CameraPreview(session: preview.session)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            recordButton
            if let message = recorder.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            recentSection
        }
        .padding(22)
        .frame(width: 440)
        .task { await recorder.refreshSources() }
        .onChange(of: recorder.phase) { previous, phase in
            guard previous == .idle, case .countdown = phase else { return }
            openWindow(id: RecordingPanelView.windowID)
            if recorder.session?.deviceCapture?.hasCamera == true {
                openWindow(id: CameraBubbleView.windowID)
            }
            dismissWindow(id: RecorderView.windowID)
        }
        .onChange(of: recorder.selectedCameraID) { recorder.updatePreview() }
        .onChange(of: recorder.sourceKind) { Task { await recorder.sourceKindDidChange() } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenSail")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Record your screen, camera and voice.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await recorder.refreshSources() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh displays, windows and devices")
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Screen Recording permission needed", systemImage: "lock.shield")
                .font(.headline)
            Text("macOS requires permission before ScreenSail can capture your screen. After enabling ScreenSail in System Settings, relaunch the app for it to take effect.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Allow Screen Recording") { recorder.requestScreenAccess() }
                    .buttonStyle(.borderedProminent)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Relaunch ScreenSail") { recorder.relaunch() }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func sourceSection(recorder: Bindable<RecorderController>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Source", selection: recorder.sourceKind) {
                ForEach(RecorderController.SourceKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch recorder.wrappedValue.sourceKind {
            case .camera:
                Text("Records only your camera, like a video message.")
                    .foregroundStyle(.secondary)
            case .display:
                Picker("Display", selection: recorder.selectedDisplayID) {
                    ForEach(recorder.wrappedValue.displays) { target in
                        Text("\(target.title) · \(target.subtitle)").tag(Optional(target.id))
                    }
                }
            case .window:
                if recorder.wrappedValue.windows.isEmpty {
                    Text("No windows found. Open a window and refresh.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Window", selection: recorder.selectedWindowID) {
                        ForEach(recorder.wrappedValue.windows) { target in
                            Text("\(target.subtitle) — \(target.title)").tag(Optional(target.id))
                        }
                    }
                }
            }
        }
    }

    private func devicesSection(recorder: Bindable<RecorderController>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Camera", isOn: Binding(
                    get: { recorder.wrappedValue.usesCamera },
                    set: { value in Task { await recorder.wrappedValue.setCameraEnabled(value) } }
                ))
                .toggleStyle(.switch)
                .frame(width: 130, alignment: .leading)
                .disabled(recorder.wrappedValue.isCameraOnly)
                Picker("", selection: recorder.selectedCameraID) {
                    ForEach(recorder.wrappedValue.cameras, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(Optional(device.uniqueID))
                    }
                }
                .labelsHidden()
                .disabled(!recorder.wrappedValue.usesCamera)
            }
            HStack {
                Toggle("Microphone", isOn: Binding(
                    get: { recorder.wrappedValue.microphoneEnabled },
                    set: { value in Task { await recorder.wrappedValue.setMicrophoneEnabled(value) } }
                ))
                .toggleStyle(.switch)
                .frame(width: 130, alignment: .leading)
                Picker("", selection: recorder.selectedMicrophoneID) {
                    ForEach(recorder.wrappedValue.microphones, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(Optional(device.uniqueID))
                    }
                }
                .labelsHidden()
                .disabled(!recorder.wrappedValue.microphoneEnabled)
            }
            Toggle("System audio", isOn: recorder.systemAudioEnabled)
                .toggleStyle(.switch)
                .disabled(recorder.wrappedValue.isCameraOnly)
        }
        .disabled(!recorder.wrappedValue.isIdle)
    }

    private var recordButton: some View {
        Button {
            recorder.startRecording()
        } label: {
            Label(recorder.isIdle ? "Start Recording" : "Recording…", systemImage: "record.circle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .disabled(!recorder.canRecord)
        .keyboardShortcut("r", modifiers: .command)
    }

    @ViewBuilder
    private var recentSection: some View {
        if !recorder.recentProjects.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent recordings")
                    .font(.headline)
                ForEach(recorder.recentProjects.prefix(5), id: \.self) { url in
                    HStack {
                        Button {
                            openWindow(value: url)
                        } label: {
                            Label(url.deletingPathExtension().lastPathComponent, systemImage: "film")
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Show in Finder")
                    }
                }
            }
        }
    }
}
