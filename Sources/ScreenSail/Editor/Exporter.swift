import AVFoundation

enum ExportError: LocalizedError {
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable: "The export could not be started."
        }
    }
}

enum Exporter {
    static func export(
        asset: AVAsset,
        videoComposition: AVVideoComposition,
        audioMix: AVAudioMix?,
        timeRange: CMTimeRange,
        codec: VideoCodec,
        to url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let preset = codec == .hevc ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw ExportError.sessionUnavailable
        }
        session.videoComposition = videoComposition
        session.audioMix = audioMix
        session.timeRange = timeRange
        session.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: url)

        let monitor = Task {
            for await state in session.states(updateInterval: 0.2) {
                if case .exporting(let exportProgress) = state {
                    progress(exportProgress.fractionCompleted)
                }
            }
        }
        defer { monitor.cancel() }
        try await session.export(to: url, as: .mp4)
    }
}
