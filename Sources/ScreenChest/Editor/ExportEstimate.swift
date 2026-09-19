import Foundation

enum ExportEstimate {
    static let audioBitsPerSecond: Double = 128_000

    static func fileSizeBytes(canvas: CGSize, frameRate: Int, duration: Double, codec: VideoCodec, hasAudio: Bool) -> Int64 {
        let pixelsPerSecond = canvas.width * canvas.height * Double(frameRate)
        let videoBitsPerSecond = pixelsPerSecond * codec.estimatedBitsPerPixel
        let audio = hasAudio ? audioBitsPerSecond : 0
        return Int64(((videoBitsPerSecond + audio) * max(0, duration) / 8).rounded())
    }

    static func label(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        return "~\(formatter.string(fromByteCount: bytes))"
    }
}

extension VideoCodec {
    var estimatedBitsPerPixel: Double {
        switch self {
        case .h264: 0.1
        case .hevc: 0.06
        }
    }
}
