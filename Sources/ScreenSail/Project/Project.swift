import Foundation
import CoreGraphics

struct Project: Codable, Equatable {
    var name: String
    var createdAt: Date
    var recording: RecordingInfo
    var edits: Edits
}

struct RecordingInfo: Codable, Equatable {
    var screenFile: String
    var cameraFile: String?
    var mouseFile: String
    var audioTracks: [AudioTrackKind]
    var pixelWidth: Int
    var pixelHeight: Int
    var duration: Double
    var sourceName: String

    var pixelSize: CGSize { CGSize(width: pixelWidth, height: pixelHeight) }
}

enum AudioTrackKind: String, Codable {
    case microphone
    case systemAudio
}

struct Edits: Codable, Equatable {
    var trimStart: Double
    var trimEnd: Double
    var zooms: [ZoomSegment]
    var backgroundPresetID: String
    var padding: Double
    var cornerRadius: Double
    var shadow: Bool
    var camera: CameraStyle
    var microphoneVolume: Double
    var systemAudioVolume: Double
    var output: OutputSettings

    static func initial(duration: Double, zooms: [ZoomSegment], hasCamera: Bool) -> Edits {
        Edits(
            trimStart: 0,
            trimEnd: duration,
            zooms: zooms,
            backgroundPresetID: BackgroundPreset.all[0].id,
            padding: 0.06,
            cornerRadius: 0.02,
            shadow: true,
            camera: CameraStyle(enabled: hasCamera, corner: .bottomRight, size: 0.22, shape: .circle, mirrored: true),
            microphoneVolume: 1,
            systemAudioVolume: 1,
            output: OutputSettings(resolution: .source, codec: .h264)
        )
    }

    var trimRange: ClosedRange<Double> { trimStart...max(trimStart, trimEnd) }
}

struct ZoomSegment: Codable, Equatable, Identifiable {
    var id: UUID
    var start: Double
    var end: Double
    var scale: Double
    var anchor: NormalizedPoint
    var followsCursor: Bool

    var duration: Double { end - start }

    func contains(_ time: Double) -> Bool { time >= start && time < end }
}

struct NormalizedPoint: Codable, Equatable {
    var x: Double
    var y: Double

    static let center = NormalizedPoint(x: 0.5, y: 0.5)
}

struct CameraStyle: Codable, Equatable {
    var enabled: Bool
    var corner: Corner
    var size: Double
    var shape: Shape
    var mirrored: Bool

    enum Corner: String, Codable, CaseIterable, Identifiable {
        case topLeft, topRight, bottomLeft, bottomRight
        var id: String { rawValue }
        var label: String {
            switch self {
            case .topLeft: "Top Left"
            case .topRight: "Top Right"
            case .bottomLeft: "Bottom Left"
            case .bottomRight: "Bottom Right"
            }
        }
    }

    enum Shape: String, Codable, CaseIterable, Identifiable {
        case circle, rounded
        var id: String { rawValue }
        var label: String {
            switch self {
            case .circle: "Circle"
            case .rounded: "Rounded"
            }
        }
    }
}

struct OutputSettings: Codable, Equatable {
    var resolution: OutputResolution
    var codec: VideoCodec
}

enum OutputResolution: String, Codable, CaseIterable, Identifiable {
    case source, p1440, p1080, p720
    var id: String { rawValue }
    var label: String {
        switch self {
        case .source: "Source"
        case .p1440: "1440p"
        case .p1080: "1080p"
        case .p720: "720p"
        }
    }
    var maxHeight: Int? {
        switch self {
        case .source: nil
        case .p1440: 1440
        case .p1080: 1080
        case .p720: 720
        }
    }
}

enum VideoCodec: String, Codable, CaseIterable, Identifiable {
    case h264, hevc
    var id: String { rawValue }
    var label: String {
        switch self {
        case .h264: "H.264 (compatible)"
        case .hevc: "HEVC (smaller)"
        }
    }
}

struct RGB: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
}

struct BackgroundPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let top: RGB
    let bottom: RGB

    static let all: [BackgroundPreset] = [
        BackgroundPreset(id: "ocean", name: "Ocean", top: RGB(r: 0.16, g: 0.44, b: 0.88), bottom: RGB(r: 0.07, g: 0.12, b: 0.36)),
        BackgroundPreset(id: "sunset", name: "Sunset", top: RGB(r: 0.98, g: 0.55, b: 0.28), bottom: RGB(r: 0.72, g: 0.18, b: 0.45)),
        BackgroundPreset(id: "forest", name: "Forest", top: RGB(r: 0.20, g: 0.62, b: 0.45), bottom: RGB(r: 0.05, g: 0.25, b: 0.22)),
        BackgroundPreset(id: "lavender", name: "Lavender", top: RGB(r: 0.62, g: 0.50, b: 0.92), bottom: RGB(r: 0.28, g: 0.18, b: 0.55)),
        BackgroundPreset(id: "graphite", name: "Graphite", top: RGB(r: 0.30, g: 0.31, b: 0.34), bottom: RGB(r: 0.10, g: 0.10, b: 0.12)),
        BackgroundPreset(id: "snow", name: "Snow", top: RGB(r: 0.97, g: 0.97, b: 0.98), bottom: RGB(r: 0.86, g: 0.87, b: 0.90)),
    ]

    static func named(_ id: String) -> BackgroundPreset {
        all.first { $0.id == id } ?? all[0]
    }
}
