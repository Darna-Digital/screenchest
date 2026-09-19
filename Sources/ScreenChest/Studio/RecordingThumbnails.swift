import AVFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class RecordingThumbnails {
    nonisolated static let pixelSize = CGSize(width: 192, height: 120)

    private var images: [URL: CGImage] = [:]
    @ObservationIgnored private var inFlight: Set<URL> = []

    func image(for recording: LibraryRecording) -> CGImage? {
        images[recording.url]
    }

    func load(_ recording: LibraryRecording) {
        let url = recording.url
        guard images[url] == nil, !inFlight.contains(url) else { return }
        inFlight.insert(url)
        Task {
            let image = await Self.generate(for: url, duration: recording.duration)
            inFlight.remove(url)
            if let image { images[url] = image }
        }
    }

    private nonisolated static func generate(for packageURL: URL, duration: Double) async -> CGImage? {
        let asset = AVURLAsset(url: packageURL.appendingPathComponent(ProjectStore.screenFileName))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = pixelSize
        let time = CMTime(seconds: min(0.5, duration / 2), preferredTimescale: 600)
        return try? await generator.image(at: time).image
    }
}

struct RecordingThumbnail: View {
    let image: CGImage?
    var width: CGFloat = 40

    private var height: CGFloat { width * 0.625 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: width * 0.1, style: .continuous) }

    var body: some View {
        ZStack {
            shape.fill(.quaternary)
            if let image {
                Image(image, scale: 1, label: Text("Recording preview"))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                Image(systemName: "film")
                    .font(.system(size: height * 0.45))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
        .animation(.easeOut(duration: 0.2), value: image == nil)
    }
}
