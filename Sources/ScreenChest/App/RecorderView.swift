import AppKit
import AVFoundation
import SwiftUI

struct RecorderView: View {
    static let windowID = "recorder"
    static let itemCornerRadius: CGFloat = 12

    @Environment(RecorderController.self) private var recorder
    @Environment(StudioLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 10) {
            toolbar
            if !recorder.hasScreenAccess, !recorder.isCameraOnly {
                permissionRow
            }
            if let message = recorder.errorMessage {
                messageRow(message)
            }
        }
        .padding(FloatingPanel.windowPadding)
        .environment(\.colorScheme, .dark)
        .task { await recorder.refreshSources() }
        .onAppear {
            recorder.updatePreview()
            syncCameraBubble()
        }
        .onDisappear {
            if recorder.phase == .idle { recorder.stopPreview() }
        }
        .onChange(of: recorder.cameraBubbleSession == nil) { syncCameraBubble() }
        .onChange(of: recorder.phase) { previous, phase in
            guard previous == .idle, case .countdown = phase else { return }
            openWindow(id: RecordingPanelView.windowID)
            syncCameraBubble()
            dismissWindow(id: RecorderView.windowID)
        }
        .onChange(of: recorder.selectedCameraID) { recorder.updatePreview() }
        .onChange(of: recorder.sourceKind) { Task { await recorder.sourceKindDidChange() } }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            ToolbarIconButton(systemImage: "xmark", help: "Close") {
                dismissWindow(id: RecorderView.windowID)
            }
            ToolbarDivider()
            sourceButtons
            ToolbarDivider()
            cameraMenu
            microphoneMenu
            systemAudioButton
            ToolbarDivider()
            settingsMenu
            studioButton
            recordButton
        }
        .padding(8)
        .floatingPanel()
        .movesWindowOnDrag()
    }

    @ViewBuilder
    private var sourceButtons: some View {
        if recorder.displays.count > 1 {
            Menu {
                ForEach(recorder.displays) { display in
                    Button("\(display.title) · \(display.subtitle)") {
                        recorder.selectedDisplayID = display.id
                        recorder.sourceKind = .display
                    }
                }
            } label: {
                SourceLabel(systemImage: "display", title: "Display", isSelected: recorder.sourceKind == .display)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        } else {
            Button {
                recorder.sourceKind = .display
            } label: {
                SourceLabel(systemImage: "display", title: "Display", isSelected: recorder.sourceKind == .display)
            }
            .buttonStyle(.plain)
        }

        Menu {
            if recorder.windows.isEmpty {
                Text("No windows found")
            }
            ForEach(recorder.windows) { window in
                Button("\(window.subtitle) — \(window.title)") {
                    recorder.selectedWindowID = window.id
                    recorder.sourceKind = .window
                }
            }
            Divider()
            Button("Refresh Windows") { Task { await recorder.refreshSources() } }
        } label: {
            SourceLabel(
                systemImage: "macwindow",
                title: recorder.sourceKind == .window ? (recorder.selectedTarget?.subtitle ?? "Window") : "Window",
                isSelected: recorder.sourceKind == .window
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)

        Button {
            recorder.sourceKind = .camera
        } label: {
            SourceLabel(systemImage: "web.camera", title: "Camera", isSelected: recorder.sourceKind == .camera)
        }
        .buttonStyle(.plain)
    }

    private var cameraMenu: some View {
        Menu {
            Button("No camera") { Task { await recorder.setCameraEnabled(false) } }
                .disabled(recorder.isCameraOnly)
            Divider()
            ForEach(recorder.cameras, id: \.uniqueID) { device in
                Button(device.localizedName) {
                    recorder.selectedCameraID = device.uniqueID
                    Task { await recorder.setCameraEnabled(true) }
                }
            }
        } label: {
            DeviceLabel(
                systemImage: recorder.usesCamera ? "video" : "video.slash",
                title: recorder.usesCamera ? (recorder.selectedCamera?.localizedName ?? "No camera") : "No camera",
                isActive: recorder.usesCamera
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var microphoneMenu: some View {
        Menu {
            Button("No microphone") { Task { await recorder.setMicrophoneEnabled(false) } }
            Divider()
            ForEach(recorder.microphones, id: \.uniqueID) { device in
                Button(device.localizedName) {
                    recorder.selectedMicrophoneID = device.uniqueID
                    Task { await recorder.setMicrophoneEnabled(true) }
                }
            }
        } label: {
            DeviceLabel(
                systemImage: recorder.microphoneEnabled ? "mic" : "mic.slash",
                title: recorder.microphoneEnabled ? (recorder.selectedMicrophone?.localizedName ?? "No microphone") : "No microphone",
                isActive: recorder.microphoneEnabled
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var systemAudioButton: some View {
        Button {
            recorder.systemAudioEnabled.toggle()
        } label: {
            DeviceLabel(
                systemImage: recorder.systemAudioEnabled && !recorder.isCameraOnly ? "speaker.wave.2" : "speaker.slash",
                title: recorder.systemAudioEnabled && !recorder.isCameraOnly ? "System audio" : "No system audio",
                isActive: recorder.systemAudioEnabled && !recorder.isCameraOnly
            )
        }
        .buttonStyle(.plain)
        .disabled(recorder.isCameraOnly)
    }

    private var settingsMenu: some View {
        Menu {
            Section("Recent recordings") {
                if recorder.recentProjects.isEmpty {
                    Text("No recordings yet")
                }
                ForEach(recorder.recentProjects.prefix(6), id: \.self) { url in
                    Button(url.deletingPathExtension().lastPathComponent) { openStudio(showing: url) }
                }
            }
            Divider()
            Button("Open Recordings Folder") {
                try? FileManager.default.createDirectory(at: ProjectStore.libraryURL, withIntermediateDirectories: true)
                NSWorkspace.shared.open(ProjectStore.libraryURL)
            }
            Button("Refresh Sources") { Task { await recorder.refreshSources() } }
            if !recorder.hasScreenAccess {
                Divider()
                Button("Allow Screen Recording") { recorder.requestScreenAccess() }
                Button("Relaunch ScreenChest") { recorder.relaunch() }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 40, height: 56)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .foregroundStyle(.secondary)
    }

    private var studioButton: some View {
        Button {
            openStudio(showing: nil)
        } label: {
            Image(systemName: "film.stack")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 40, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Open Studio (⌘2)")
    }

    private func openStudio(showing url: URL?) {
        if let url { library.open(url) }
        openWindow(id: StudioView.windowID)
        dismissWindow(id: RecorderView.windowID)
    }

    private var recordButton: some View {
        ProminentPanelButton(
            title: "Record",
            systemImage: "circle.fill",
            tint: recorder.canRecord ? .red : .gray.opacity(0.5)
        ) {
            recorder.startRecording()
        }
        .disabled(!recorder.canRecord)
        .keyboardShortcut("r", modifiers: .command)
        .help(recorder.canRecord ? "Start recording (⌘R)" : "Choose a source first")
    }

    private var permissionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Recording permission needed")
                    .font(.headline)
                Text("Allow ScreenChest in System Settings, then relaunch.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Allow") { recorder.requestScreenAccess() }
            Button("Relaunch") { recorder.relaunch() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .floatingPanel(cornerRadius: 18)
    }

    private func messageRow(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                recorder.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .floatingPanel(cornerRadius: 18)
    }

    private func syncCameraBubble() {
        if recorder.cameraBubbleSession != nil {
            openWindow(id: CameraBubbleView.windowID)
        } else {
            dismissWindow(id: CameraBubbleView.windowID)
        }
    }
}

private struct SourceLabel: View {
    let systemImage: String
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .regular))
                .frame(height: 26)
            Text(DeviceLabel.shortened(title))
                .font(.system(size: 11))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(isSelected ? .primary : .secondary)
        .frame(minWidth: 76)
        .frame(height: 56)
        .background(isSelected ? Color.white.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: RecorderView.itemCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: RecorderView.itemCornerRadius, style: .continuous))
    }
}

private struct DeviceLabel: View {
    static let maximumTitleLength = 24

    let systemImage: String
    let title: String
    let isActive: Bool

    static func shortened(_ title: String) -> String {
        title.count > maximumTitleLength ? String(title.prefix(maximumTitleLength - 1)) + "…" : title
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
            Text(DeviceLabel.shortened(title))
                .font(.system(size: 14))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(isActive ? .primary : .secondary)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(isActive ? Color.white.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: RecorderView.itemCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: RecorderView.itemCornerRadius, style: .continuous))
    }
}

private struct ToolbarIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 44, height: 56)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: RecorderView.itemCornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: RecorderView.itemCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.14))
            .frame(width: 1, height: 40)
            .padding(.horizontal, 4)
    }
}
