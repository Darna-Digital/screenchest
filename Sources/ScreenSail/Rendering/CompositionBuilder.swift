import AVFoundation

struct EditorComposition {
    let composition: AVMutableComposition
    let screenTrackID: CMPersistentTrackID
    let cameraTrackID: CMPersistentTrackID?
    let microphoneTrack: AVMutableCompositionTrack?
    let systemAudioTrack: AVMutableCompositionTrack?
    let duration: CMTime
}

enum CompositionError: LocalizedError {
    case missingScreenVideo
    case trackCreationFailed

    var errorDescription: String? {
        switch self {
        case .missingScreenVideo: "The recording has no screen video track."
        case .trackCreationFailed: "The editing timeline could not be created."
        }
    }
}

enum CompositionBuilder {
    static func build(project: Project, packageURL: URL) async throws -> EditorComposition {
        let composition = AVMutableComposition()
        var duration = CMTime.zero

        let screenAsset = AVURLAsset(url: packageURL.appendingPathComponent(project.recording.screenFile))
        guard let screenSource = try await screenAsset.loadTracks(withMediaType: .video).first else {
            throw CompositionError.missingScreenVideo
        }
        let screenTrack = try addTrack(.video, to: composition)
        let screenRange = try await screenSource.load(.timeRange)
        try screenTrack.insertTimeRange(screenRange, of: screenSource, at: screenRange.start)
        duration = CMTimeMaximum(duration, screenRange.end)

        var microphoneTrack: AVMutableCompositionTrack?
        var systemAudioTrack: AVMutableCompositionTrack?
        let audioSources = try await screenAsset.loadTracks(withMediaType: .audio).sorted { $0.trackID < $1.trackID }
        for (index, kind) in project.recording.audioTracks.enumerated() where index < audioSources.count {
            let source = audioSources[index]
            let range = try await source.load(.timeRange)
            let track = try addTrack(.audio, to: composition)
            try track.insertTimeRange(range, of: source, at: range.start)
            duration = CMTimeMaximum(duration, range.end)
            switch kind {
            case .microphone: microphoneTrack = track
            case .systemAudio: systemAudioTrack = track
            }
        }

        var cameraTrackID: CMPersistentTrackID?
        if let cameraFile = project.recording.cameraFile {
            let cameraAsset = AVURLAsset(url: packageURL.appendingPathComponent(cameraFile))
            if let cameraSource = try await cameraAsset.loadTracks(withMediaType: .video).first {
                let range = try await cameraSource.load(.timeRange)
                let track = try addTrack(.video, to: composition)
                try track.insertTimeRange(range, of: cameraSource, at: range.start)
                duration = CMTimeMaximum(duration, range.end)
                cameraTrackID = track.trackID
            }
        }

        return EditorComposition(
            composition: composition,
            screenTrackID: screenTrack.trackID,
            cameraTrackID: cameraTrackID,
            microphoneTrack: microphoneTrack,
            systemAudioTrack: systemAudioTrack,
            duration: duration
        )
    }

    static func makeVideoComposition(for editor: EditorComposition, plan: RenderPlan, frameRate: Int) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = SailVideoCompositor.self
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        videoComposition.renderSize = plan.canvasSize
        videoComposition.instructions = [
            SailCompositionInstruction(
                timeRange: CMTimeRange(start: .zero, duration: editor.duration),
                plan: plan,
                screenTrackID: editor.screenTrackID,
                cameraTrackID: plan.cameraRect == nil ? nil : editor.cameraTrackID
            )
        ]
        return videoComposition
    }

    static func makeAudioMix(for editor: EditorComposition, edits: Edits) -> AVMutableAudioMix? {
        var parameters: [AVMutableAudioMixInputParameters] = []
        if let track = editor.microphoneTrack {
            let input = AVMutableAudioMixInputParameters(track: track)
            input.setVolume(Float(edits.microphoneVolume), at: .zero)
            parameters.append(input)
        }
        if let track = editor.systemAudioTrack {
            let input = AVMutableAudioMixInputParameters(track: track)
            input.setVolume(Float(edits.systemAudioVolume), at: .zero)
            parameters.append(input)
        }
        guard !parameters.isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = parameters
        return mix
    }

    private static func addTrack(_ mediaType: AVMediaType, to composition: AVMutableComposition) throws -> AVMutableCompositionTrack {
        guard let track = composition.addMutableTrack(withMediaType: mediaType, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CompositionError.trackCreationFailed
        }
        return track
    }
}
