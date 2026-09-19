import Foundation
import CoreGraphics

struct Project: Codable, Equatable {
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

    static func initial(duration: Double, zooms: [ZoomSegment], hasCamera: Bool, cameraCorner: CameraStyle.Corner = .bottomRight) -> Edits {
        Edits(
            trimStart: 0,
            trimEnd: duration,
            zooms: zooms,
            backgroundPresetID: BackgroundPreset.none.id,
            padding: 0.06,
            cornerRadius: 0.02,
            shadow: true,
            camera: CameraStyle(enabled: hasCamera, corner: cameraCorner, size: 0.22, shape: .circle, mirrored: true),
            microphoneVolume: 1,
            systemAudioVolume: 1,
            output: OutputSettings(resolution: .source, codec: .h264)
        )
    }

    var trimRange: ClosedRange<Double> { trimStart...max(trimStart, trimEnd) }

    init(trimStart: Double, trimEnd: Double, zooms: [ZoomSegment], backgroundPresetID: String, padding: Double, cornerRadius: Double, shadow: Bool, camera: CameraStyle, microphoneVolume: Double, systemAudioVolume: Double, output: OutputSettings) {
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.zooms = zooms
        self.backgroundPresetID = backgroundPresetID
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.camera = camera
        self.microphoneVolume = microphoneVolume
        self.systemAudioVolume = systemAudioVolume
        self.output = output
    }

    private enum LegacyClipKeys: String, CodingKey {
        case clips
    }

    private struct LegacyClip: Decodable {
        var start: Double
        var end: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyClips = try decoder.container(keyedBy: LegacyClipKeys.self).decodeIfPresent([LegacyClip].self, forKey: .clips) ?? []
        trimStart = try container.decodeIfPresent(Double.self, forKey: .trimStart) ?? legacyClips.map(\.start).min() ?? 0
        trimEnd = try container.decodeIfPresent(Double.self, forKey: .trimEnd) ?? legacyClips.map(\.end).max() ?? .infinity
        zooms = try container.decode([ZoomSegment].self, forKey: .zooms)
        backgroundPresetID = try container.decode(String.self, forKey: .backgroundPresetID)
        padding = try container.decode(Double.self, forKey: .padding)
        cornerRadius = try container.decode(Double.self, forKey: .cornerRadius)
        shadow = try container.decode(Bool.self, forKey: .shadow)
        camera = try container.decode(CameraStyle.self, forKey: .camera)
        microphoneVolume = try container.decode(Double.self, forKey: .microphoneVolume)
        systemAudioVolume = try container.decode(Double.self, forKey: .systemAudioVolume)
        output = try container.decode(OutputSettings.self, forKey: .output)
    }

    mutating func clampTrim(to duration: Double) {
        trimEnd = min(max(trimEnd, 0), duration)
        trimStart = min(max(trimStart, 0), trimEnd)
    }
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

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
}

struct BackgroundPreset: Identifiable, Equatable {
    struct Glow: Equatable {
        var color: RGB
        var center: NormalizedPoint
        var radius: Double
        var opacity: Double
    }

    struct Gradient: Equatable {
        var stops: [RGB]
        var angle: Double
        var glows: [Glow]
    }

    enum Fill: Equatable {
        case none
        case gradient(Gradient)
        case image(URL)
    }

    let id: String
    let name: String
    let fill: Fill

    var isNone: Bool { fill == .none }

    static let none = BackgroundPreset(id: "none", name: "None", fill: .none)

    static let wallpaperIDPrefix = "wallpaper:"
    static let desktopPictureID = "desktop"

    static let gradients: [BackgroundPreset] = [
        gradient("ocean", "Ocean", [0x2563EB, 0x0B1B4D], angle: 135, glows: [Glow(0x38BDF8, at: 0.85, 0.15, radius: 0.6, opacity: 0.45)]),
        gradient("sky", "Sky", [0x7DD3FC, 0x2563EB], angle: 160, glows: [Glow(0xE0F2FE, at: 0.3, 0.1, radius: 0.6, opacity: 0.6)]),
        gradient("aurora", "Aurora", [0x0B1220, 0x0F2A2E], angle: 150, glows: [
            Glow(0x22D3EE, at: 0.25, 0.2, radius: 0.5, opacity: 0.7),
            Glow(0xA855F7, at: 0.8, 0.75, radius: 0.55, opacity: 0.7),
            Glow(0x4ADE80, at: 0.6, 0.05, radius: 0.35, opacity: 0.5),
        ]),
        gradient("midnight", "Midnight", [0x1E1B4B, 0x0A0716], angle: 180, glows: [Glow(0x6366F1, at: 0.5, 0.0, radius: 0.7, opacity: 0.7)]),
        gradient("lavender", "Lavender", [0xA78BFA, 0x5B21B6, 0x1E1B4B], angle: 135, glows: [Glow(0xF0ABFC, at: 0.8, 0.2, radius: 0.55, opacity: 0.45)]),
        gradient("candy", "Candy", [0xF472B6, 0x8B5CF6, 0x3B82F6], angle: 120, glows: [Glow(0xFFFFFF, at: 0.3, 0.25, radius: 0.4, opacity: 0.35)]),
        gradient("sunset", "Sunset", [0xF97316, 0xDB2777, 0x4C1D95], angle: 160, glows: [Glow(0xFDE68A, at: 0.2, 0.15, radius: 0.5, opacity: 0.5)]),
        gradient("rose", "Rosé", [0xFDA4AF, 0xE11D48, 0x881337], angle: 145, glows: [Glow(0xFFE4E6, at: 0.15, 0.2, radius: 0.45, opacity: 0.5)]),
        gradient("peach", "Peach", [0xFFD1B3, 0xFFA07A, 0xFF7E9D], angle: 135, glows: [Glow(0xFFF1E6, at: 0.2, 0.2, radius: 0.5, opacity: 0.6)]),
        gradient("gold", "Gold", [0xFBBF24, 0xB45309, 0x451A03], angle: 150, glows: [Glow(0xFEF3C7, at: 0.25, 0.2, radius: 0.5, opacity: 0.5)]),
        gradient("ember", "Ember", [0x0F131C, 0x000000], angle: 180, glows: [
            Glow(0xF97316, at: 0.85, 0.9, radius: 0.6, opacity: 0.85),
            Glow(0xDC2626, at: 0.2, 0.85, radius: 0.5, opacity: 0.6),
        ]),
        gradient("forest", "Forest", [0x10B981, 0x064E3B], angle: 135, glows: [Glow(0xA3E635, at: 0.15, 0.85, radius: 0.5, opacity: 0.3)]),
        gradient("mint", "Mint", [0xCCFBF1, 0x5EEAD4, 0x0D9488], angle: 135, glows: [Glow(0xFFFFFF, at: 0.2, 0.15, radius: 0.5, opacity: 0.5)]),
        gradient("slate", "Slate", [0x64748B, 0x1E293B], angle: 135, glows: [Glow(0xCBD5E1, at: 0.2, 0.2, radius: 0.5, opacity: 0.3)]),
        gradient("graphite", "Graphite", [0x3F3F46, 0x18181B, 0x09090B], angle: 135, glows: [Glow(0x71717A, at: 0.3, 0.2, radius: 0.6, opacity: 0.35)]),
        gradient("snow", "Snow", [0xFFFFFF, 0xE2E8F0], angle: 135, glows: [Glow(0xC7D2FE, at: 0.8, 0.2, radius: 0.6, opacity: 0.5)]),
    ]

    static var all: [BackgroundPreset] { [none] + gradients + BackgroundLibrary.wallpapers }

    static func named(_ id: String) -> BackgroundPreset {
        all.first { $0.id == id } ?? gradients[0]
    }

    static func wallpaper(named name: String, url: URL) -> BackgroundPreset {
        BackgroundPreset(id: wallpaperIDPrefix + name, name: name, fill: .image(url))
    }

    static func desktopPicture(url: URL) -> BackgroundPreset {
        BackgroundPreset(id: desktopPictureID, name: "Your Desktop", fill: .image(url))
    }

    private static func gradient(_ id: String, _ name: String, _ stops: [UInt32], angle: Double, glows: [Glow]) -> BackgroundPreset {
        BackgroundPreset(id: id, name: name, fill: .gradient(Gradient(stops: stops.map { RGB(hex: $0) }, angle: angle, glows: glows)))
    }
}

private extension BackgroundPreset.Glow {
    init(_ hex: UInt32, at x: Double, _ y: Double, radius: Double, opacity: Double) {
        self.init(color: RGB(hex: hex), center: NormalizedPoint(x: x, y: y), radius: radius, opacity: opacity)
    }
}
