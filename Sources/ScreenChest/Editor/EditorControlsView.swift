import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorControlSections: View {
    let model: EditorModel

    var body: some View {
        zoomSection
        backgroundSection
        if model.hasCamera {
            cameraSection
        }
        if model.hasMicrophone || model.hasSystemAudio {
            audioSection
        }
        exportSection
    }

    private var zoomSection: some View {
        Section("Zoom") {
            HStack {
                Button("Add at Playhead") { model.addZoomAtPlayhead() }
                Button("Auto-generate") { model.regenerateZooms() }
            }
            Text("\(model.edits.zooms.count) zoom \(model.edits.zooms.count == 1 ? "segment" : "segments") · \(model.mouse.clicks.count) clicks detected")
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.selectedZoom != nil {
                LabeledSlider(
                    title: "Scale",
                    value: model.selectedZoomBinding(\.scale, default: AutoZoom.defaultScale),
                    range: 1.2...4,
                    format: { String(format: "%.1f×", $0) }
                )
                LabeledSlider(
                    title: "Duration",
                    value: Binding(
                        get: { model.selectedZoom?.duration ?? 0 },
                        set: { model.setSelectedZoomDuration($0) }
                    ),
                    range: EditorModel.minimumZoomDuration...max(EditorModel.minimumZoomDuration + 0.1, model.selectedZoomMaximumDuration),
                    format: { String(format: "%.1fs", $0) }
                )
                Toggle("Follow cursor", isOn: model.selectedZoomBinding(\.followsCursor, default: true))
                Button("Delete Zoom", role: .destructive) { model.deleteSelectedZoom() }
            } else {
                Text("Select a zoom on the timeline to edit it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var backgroundSection: some View {
        Section("Background") {
            BackgroundPicker(model: model)
            if !model.usesNoBackground {
                LabeledSlider(title: "Padding", value: model.binding(\.padding), range: 0...0.16, format: { String(format: "%.0f%%", $0 * 100) })
                LabeledSlider(title: "Corners", value: model.binding(\.cornerRadius), range: 0...0.08, format: { String(format: "%.0f%%", $0 * 100) })
                Toggle("Shadow", isOn: model.binding(\.shadow))
            }
        }
    }

    private var cameraSection: some View {
        Section("Camera") {
            Toggle("Show camera", isOn: model.binding(\.camera.enabled))
            Picker("Position", selection: model.binding(\.camera.corner)) {
                ForEach(CameraStyle.Corner.allCases) { corner in
                    Text(corner.label).tag(corner)
                }
            }
            Picker("Shape", selection: model.binding(\.camera.shape)) {
                ForEach(CameraStyle.Shape.allCases) { shape in
                    Text(shape.label).tag(shape)
                }
            }
            .pickerStyle(.segmented)
            LabeledSlider(title: "Size", value: model.binding(\.camera.size), range: 0.12...0.4, format: { String(format: "%.0f%%", $0 * 100) })
            Toggle("Mirror", isOn: model.binding(\.camera.mirrored))
        }
    }

    private var audioSection: some View {
        Section("Audio") {
            if model.hasMicrophone {
                LabeledSlider(title: "Microphone", value: model.binding(\.microphoneVolume), range: 0...2, format: { String(format: "%.0f%%", $0 * 100) })
            }
            if model.hasSystemAudio {
                LabeledSlider(title: "System", value: model.binding(\.systemAudioVolume), range: 0...2, format: { String(format: "%.0f%%", $0 * 100) })
            }
        }
    }

    private var exportSection: some View {
        Section("Export") {
            Picker("Resolution", selection: model.binding(\.output.resolution)) {
                ForEach(OutputResolution.allCases) { resolution in
                    Text(resolution.label).tag(resolution)
                }
            }
            Picker("Codec", selection: model.binding(\.output.codec)) {
                ForEach(VideoCodec.allCases) { codec in
                    Text(codec.label).tag(codec)
                }
            }
            let canvas = RenderPlan.canvasSize(for: model.project.recording.pixelSize, resolution: model.edits.output.resolution)
            Text("\(Int(canvas.width)) × \(Int(canvas.height)) · \(TimeFormatting.precise(model.edits.trimEnd - model.edits.trimStart)) · 60 fps")
                .font(.caption)
                .foregroundStyle(.secondary)

            switch model.exportState {
            case .exporting(let fraction):
                ProgressView(value: fraction) {
                    Text("Exporting… \(Int(fraction * 100))%")
                }
                Button("Cancel") { model.cancelExport() }
            case .finished(let url):
                Label("Exported", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    Button("Export Again…") { chooseDestinationAndExport() }
                }
            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Try Again…") { chooseDestinationAndExport() }
            case .idle:
                Button("Export Video…") { chooseDestinationAndExport() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("e", modifiers: .command)
            }
        }
    }

    private func chooseDestinationAndExport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.directoryURL = ProjectStore.libraryURL
        panel.nameFieldStringValue = "\(model.project.name).mp4"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.export(to: url)
    }
}

private enum BackgroundTab: String, CaseIterable, Identifiable {
    case gradients = "Gradients"
    case wallpapers = "macOS"

    var id: String { rawValue }

    var presets: [BackgroundPreset] {
        switch self {
        case .gradients: BackgroundPreset.gradients
        case .wallpapers: BackgroundLibrary.wallpapers
        }
    }

    static func containing(_ presetID: String) -> BackgroundTab {
        allCases.first { $0.presets.contains { $0.id == presetID } } ?? .gradients
    }
}

private struct BackgroundPicker: View {
    static let swatchSize = CGSize(width: 62, height: 40)

    let model: EditorModel
    @State private var tab: BackgroundTab

    init(model: EditorModel) {
        self.model = model
        _tab = State(initialValue: BackgroundTab.containing(model.edits.backgroundPresetID))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !BackgroundLibrary.wallpapers.isEmpty {
                Picker("Background type", selection: $tab) {
                    ForEach(BackgroundTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: BackgroundPicker.swatchSize.width), spacing: 8)], spacing: 8) {
                ForEach([BackgroundPreset.none] + tab.presets) { preset in
                    BackgroundSwatch(preset: preset, isSelected: model.edits.backgroundPresetID == preset.id) {
                        model.update { $0.backgroundPresetID = preset.id }
                    }
                }
            }
        }
    }
}

private struct BackgroundSwatch: View {
    let preset: BackgroundPreset
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Group {
                if preset.isNone {
                    Image(systemName: "circle.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.12))
                } else if let thumbnail = BackgroundThumbnails.shared.image(for: preset) {
                    Image(decorative: thumbnail, scale: BackgroundThumbnails.scale)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.2)
                }
            }
            .frame(width: BackgroundPicker.swatchSize.width, height: BackgroundPicker.swatchSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .help(preset.name)
        .accessibilityLabel(preset.name)
    }
}

@MainActor
@Observable
private final class BackgroundThumbnails {
    static let shared = BackgroundThumbnails()
    static let scale: CGFloat = 2

    private(set) var images: [String: CGImage] = [:]
    @ObservationIgnored private var requested: Set<String> = []

    func image(for preset: BackgroundPreset) -> CGImage? {
        if let image = images[preset.id] { return image }
        guard !requested.contains(preset.id) else { return nil }
        requested.insert(preset.id)
        let pixelSize = CGSize(width: BackgroundPicker.swatchSize.width * BackgroundThumbnails.scale, height: BackgroundPicker.swatchSize.height * BackgroundThumbnails.scale)
        Task.detached(priority: .utility) {
            let image = BackgroundPainter.render(preset, size: pixelSize)
            await MainActor.run {
                if let image { self.images[preset.id] = image }
            }
        }
        return nil
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range)
        }
    }
}
