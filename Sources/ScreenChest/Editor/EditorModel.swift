import AVFoundation
import Observation
import SwiftUI

enum TimelineEdge {
    case leading
    case trailing
}

@MainActor
@Observable
final class EditorModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    enum ExportState: Equatable {
        case idle
        case exporting(Double)
        case finished(URL)
        case failed(String)
    }

    static let previewFrameRate = 60
    static let minimumTrimLength = 0.1
    static let manualZoomDuration = 3.0
    static let minimumZoomDuration = 0.5
    static let autosaveDelay: Duration = .milliseconds(500)

    let packageURL: URL
    private(set) var project: Project
    private(set) var mouse: MouseTrack
    let player = AVPlayer()
    var loadState: LoadState = .loading
    var currentTime: Double = 0
    var isPlaying = false
    var selectedZoomID: UUID?
    var exportState: ExportState = .idle

    @ObservationIgnored private var composition: EditorComposition?
    @ObservationIgnored private var playerItem: AVPlayerItem?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var exportTask: Task<Void, Never>?

    init(packageURL: URL) throws {
        self.packageURL = packageURL
        var project = try ProjectStore.load(from: packageURL)
        project.edits.clampTrim(to: project.recording.duration)
        self.project = project
        mouse = ProjectStore.loadMouseTrack(from: packageURL, fileName: project.recording.mouseFile)
    }

    var name: String { ProjectStore.name(of: packageURL) }
    var edits: Edits { project.edits }
    var duration: Double { project.recording.duration }
    var hasCamera: Bool { project.recording.cameraFile != nil }
    var usesNoBackground: Bool { BackgroundPreset.named(edits.backgroundPresetID).isNone }
    var hasMicrophone: Bool { project.recording.audioTracks.contains(.microphone) }
    var hasSystemAudio: Bool { project.recording.audioTracks.contains(.systemAudio) }
    var isExporting: Bool { if case .exporting = exportState { true } else { false } }

    var selectedZoom: ZoomSegment? {
        edits.zooms.first { $0.id == selectedZoomID }
    }

    var sortedZooms: [ZoomSegment] {
        edits.zooms.sorted { $0.start < $1.start }
    }

    func load() async {
        do {
            let composition = try await CompositionBuilder.build(project: project, packageURL: packageURL)
            self.composition = composition
            let item = AVPlayerItem(asset: composition.composition)
            item.videoComposition = makeVideoComposition(preview: true)
            item.audioMix = CompositionBuilder.makeAudioMix(for: composition, edits: edits)
            playerItem = item
            player.actionAtItemEnd = .pause
            player.replaceCurrentItem(with: item)
            installObservers()
            seek(to: edits.trimStart)
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<Edits, Value>) -> Binding<Value> {
        Binding(
            get: { self.project.edits[keyPath: keyPath] },
            set: { value in self.update { $0[keyPath: keyPath] = value } }
        )
    }

    func selectedZoomBinding<Value>(_ keyPath: WritableKeyPath<ZoomSegment, Value>, default defaultValue: Value) -> Binding<Value> {
        Binding(
            get: { self.selectedZoom?[keyPath: keyPath] ?? defaultValue },
            set: { value in
                guard let id = self.selectedZoomID else { return }
                self.update { edits in
                    guard let index = edits.zooms.firstIndex(where: { $0.id == id }) else { return }
                    edits.zooms[index][keyPath: keyPath] = value
                }
            }
        )
    }

    func update(_ change: (inout Edits) -> Void) {
        var edits = project.edits
        change(&edits)
        guard edits != project.edits else { return }
        project.edits = edits
        applyEdits()
    }

    var trimmedDuration: Double { edits.trimEnd - edits.trimStart }
    var trimmedCurrentTime: Double { currentTime - edits.trimStart }

    func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            if currentTime >= edits.trimEnd - 0.01 {
                seek(to: edits.trimStart)
            }
            player.play()
        }
    }

    func seek(to seconds: Double) {
        let clamped = min(max(edits.trimStart, seconds), edits.trimEnd)
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setTrimStart(_ seconds: Double) {
        update { edits in
            edits.trimStart = min(max(0, seconds), edits.trimEnd - EditorModel.minimumTrimLength)
        }
        seek(to: edits.trimStart)
    }

    func setTrimEnd(_ seconds: Double) {
        update { edits in
            edits.trimEnd = max(min(duration, seconds), edits.trimStart + EditorModel.minimumTrimLength)
        }
        seek(to: edits.trimEnd)
    }

    func addZoomAtPlayhead() {
        addZoom(at: currentTime)
    }

    func addZoom(at time: Double) {
        if let existing = edits.zooms.first(where: { $0.contains(time) }) {
            selectedZoomID = existing.id
            return
        }
        let nextStart = edits.zooms.filter { $0.start > time }.map(\.start).min() ?? duration
        let end = min(time + EditorModel.manualZoomDuration, nextStart)
        guard end - time >= EditorModel.minimumZoomDuration else { return }
        let cursor = mouse.position(at: time)
        let segment = ZoomSegment(
            id: UUID(),
            start: time,
            end: end,
            scale: AutoZoom.defaultScale,
            anchor: NormalizedPoint(x: min(max(cursor.x, 0), 1), y: min(max(cursor.y, 0), 1)),
            followsCursor: true
        )
        update { $0.zooms.append(segment) }
        selectedZoomID = segment.id
    }

    func deleteSelectedZoom() {
        guard let id = selectedZoomID else { return }
        deleteZoom(id: id)
    }

    func deleteZoom(id: UUID) {
        update { $0.zooms.removeAll { $0.id == id } }
        if selectedZoomID == id {
            selectedZoomID = nil
        }
    }

    func resizeZoom(id: UUID, edge: TimelineEdge, to time: Double) {
        update { edits in
            guard let index = edits.zooms.firstIndex(where: { $0.id == id }) else { return }
            let segment = edits.zooms[index]
            let others = edits.zooms.filter { $0.id != id }
            switch edge {
            case .leading:
                let lower = others.filter { $0.end <= segment.start }.map(\.end).max() ?? 0
                edits.zooms[index].start = min(max(time, lower), segment.end - EditorModel.minimumZoomDuration)
            case .trailing:
                let upper = others.filter { $0.start >= segment.end }.map(\.start).min() ?? duration
                edits.zooms[index].end = max(min(time, upper), segment.start + EditorModel.minimumZoomDuration)
            }
        }
    }

    func regenerateZooms() {
        let zooms = AutoZoom.generate(from: mouse, duration: duration)
        update { $0.zooms = zooms }
        selectedZoomID = nil
    }

    func moveZoom(id: UUID, toStart requestedStart: Double) {
        update { edits in
            guard let index = edits.zooms.firstIndex(where: { $0.id == id }) else { return }
            let segment = edits.zooms[index]
            let others = edits.zooms.filter { $0.id != id }
            let lowerBound = others.filter { $0.end <= segment.start }.map(\.end).max() ?? 0
            let upperBound = (others.filter { $0.start >= segment.end }.map(\.start).min() ?? duration) - segment.duration
            guard upperBound >= lowerBound else { return }
            let start = min(max(requestedStart, lowerBound), upperBound)
            edits.zooms[index].start = start
            edits.zooms[index].end = start + segment.duration
        }
    }

    var selectedZoomMaximumDuration: Double {
        guard let segment = selectedZoom else { return EditorModel.manualZoomDuration }
        let nextStart = edits.zooms.filter { $0.id != segment.id && $0.start >= segment.end }.map(\.start).min() ?? duration
        return max(EditorModel.minimumZoomDuration, nextStart - segment.start)
    }

    func setSelectedZoomDuration(_ requested: Double) {
        guard let id = selectedZoomID else { return }
        let maximum = selectedZoomMaximumDuration
        update { edits in
            guard let index = edits.zooms.firstIndex(where: { $0.id == id }) else { return }
            let length = min(max(requested, EditorModel.minimumZoomDuration), maximum)
            edits.zooms[index].end = edits.zooms[index].start + length
        }
    }

    func export(to url: URL) {
        guard let composition, exportTask == nil else { return }
        player.pause()
        let canvas = RenderPlan.canvasSize(for: project.recording.pixelSize, resolution: edits.output.resolution)
        let plan = RenderPlan.make(project: project, mouse: mouse, canvasSize: canvas, hasCamera: composition.cameraTrackID != nil)
        let videoComposition = CompositionBuilder.makeVideoComposition(for: composition, plan: plan, frameRate: EditorModel.previewFrameRate)
        let audioMix = CompositionBuilder.makeAudioMix(for: composition, edits: edits)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: edits.trimStart, preferredTimescale: 600),
            end: CMTime(seconds: edits.trimEnd, preferredTimescale: 600)
        )
        let codec = edits.output.codec
        let asset = composition.composition
        exportState = .exporting(0)
        exportTask = Task {
            do {
                try await Exporter.export(
                    asset: asset,
                    videoComposition: videoComposition,
                    audioMix: audioMix,
                    timeRange: timeRange,
                    codec: codec,
                    to: url
                ) { fraction in
                    Task { @MainActor in
                        if case .exporting = self.exportState {
                            self.exportState = .exporting(fraction)
                        }
                    }
                }
                exportState = .finished(url)
            } catch is CancellationError {
                exportState = .idle
            } catch {
                exportState = .failed(error.localizedDescription)
            }
            exportTask = nil
        }
    }

    func cancelExport() {
        exportTask?.cancel()
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        try? ProjectStore.save(project, to: packageURL)
    }

    func close() {
        saveNow()
        exportTask?.cancel()
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        statusObservation = nil
        player.replaceCurrentItem(with: nil)
    }

    private func applyEdits() {
        guard let playerItem, let composition else { return }
        playerItem.videoComposition = makeVideoComposition(preview: true)
        playerItem.audioMix = CompositionBuilder.makeAudioMix(for: composition, edits: edits)
        if !isPlaying {
            seek(to: currentTime)
        }
        scheduleSave()
    }

    private func makeVideoComposition(preview: Bool) -> AVMutableVideoComposition? {
        guard let composition else { return nil }
        let source = project.recording.pixelSize
        let canvas = preview
            ? RenderPlan.previewCanvasSize(for: source)
            : RenderPlan.canvasSize(for: source, resolution: edits.output.resolution)
        let plan = RenderPlan.make(project: project, mouse: mouse, canvasSize: canvas, hasCamera: composition.cameraTrackID != nil)
        return CompositionBuilder.makeVideoComposition(for: composition, plan: plan, frameRate: EditorModel.previewFrameRate)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: EditorModel.autosaveDelay)
            guard !Task.isCancelled else { return }
            try? ProjectStore.save(project, to: packageURL)
        }
    }

    private func installObservers() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.playerDidAdvance(to: time.seconds)
            }
        }
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in self?.isPlaying = playing }
        }
    }

    private func playerDidAdvance(to seconds: Double) {
        guard seconds.isFinite else { return }
        if seconds < edits.trimStart {
            seek(to: edits.trimStart)
            return
        }
        currentTime = seconds
        if isPlaying, seconds >= edits.trimEnd - 0.001 {
            player.pause()
            seek(to: edits.trimEnd)
        }
    }
}
