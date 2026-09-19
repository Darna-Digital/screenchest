import AVFoundation
import CoreImage
import XCTest
@testable import ScreenChest

final class PipelineIntegrationTests: XCTestCase {
    private static let sourceSize = CGSize(width: 640, height: 400)
    private static let cameraSize = CGSize(width: 320, height: 240)
    private static let duration = 3.0
    private static let frameRate = 30

    private var packageURL: URL!

    override func setUpWithError() throws {
        packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenChestPipeline-\(UUID().uuidString)")
            .appendingPathExtension(ProjectStore.packageExtension)
        try ProjectStore.createPackage(at: packageURL)
        try Self.writeVideo(to: packageURL.appendingPathComponent(ProjectStore.screenFileName), size: Self.sourceSize) { _ in
            CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: CGRect(origin: .zero, size: Self.sourceSize))
        }
        try Self.writeVideo(to: packageURL.appendingPathComponent(ProjectStore.cameraFileName), size: Self.cameraSize) { _ in
            CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(origin: .zero, size: Self.cameraSize))
        }
        let samples = stride(from: 0.0, through: Self.duration, by: 1.0 / 60.0).map { MouseSample(t: $0, x: 0.5, y: 0.5) }
        try ProjectStore.saveMouseTrack(MouseTrack(samples: samples, clicks: [MouseClick(t: 1, x: 0.5, y: 0.5)]), to: packageURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: packageURL)
    }

    private func makeProject() -> Project {
        let mouse = ProjectStore.loadMouseTrack(from: packageURL, fileName: ProjectStore.mouseFileName)
        var edits = Edits.initial(duration: Self.duration, zooms: AutoZoom.generate(from: mouse, duration: Self.duration), hasCamera: true)
        edits.backgroundPresetID = BackgroundPreset.gradients[0].id
        edits.trimStart = 0.5
        edits.trimEnd = 2.5
        edits.output.resolution = .source
        return Project(
            createdAt: Date(),
            recording: RecordingInfo(
                screenFile: ProjectStore.screenFileName,
                cameraFile: ProjectStore.cameraFileName,
                mouseFile: ProjectStore.mouseFileName,
                audioTracks: [],
                pixelWidth: Int(Self.sourceSize.width),
                pixelHeight: Int(Self.sourceSize.height),
                duration: Self.duration,
                sourceName: "Fixture"
            ),
            edits: edits
        )
    }

    func testCompositionCarriesScreenAndCameraTracks() async throws {
        let project = makeProject()
        let composition = try await CompositionBuilder.build(project: project, packageURL: packageURL)
        XCTAssertNotNil(composition.cameraTrackID)
        XCTAssertNil(composition.microphoneTrack)
        XCTAssertEqual(composition.duration.seconds, Self.duration, accuracy: 0.05)
        let tracks = try await composition.composition.loadTracks(withMediaType: .video)
        XCTAssertEqual(tracks.count, 2)
    }

    func testExportRendersCompositedTrimmedVideo() async throws {
        let project = makeProject()
        let mouse = ProjectStore.loadMouseTrack(from: packageURL, fileName: ProjectStore.mouseFileName)
        let composition = try await CompositionBuilder.build(project: project, packageURL: packageURL)
        let canvas = RenderPlan.canvasSize(for: project.recording.pixelSize, resolution: project.edits.output.resolution)
        let plan = RenderPlan.make(project: project, mouse: mouse, canvasSize: canvas, hasCamera: true)
        let videoComposition = CompositionBuilder.makeVideoComposition(for: composition, plan: plan, frameRate: 60)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("ScreenChestExport-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let progress = ProgressLog()
        try await Exporter.export(
            asset: composition.composition,
            videoComposition: videoComposition,
            audioMix: nil,
            timeRange: CMTimeRange(start: CMTime(seconds: 0.5, preferredTimescale: 600), end: CMTime(seconds: 2.5, preferredTimescale: 600)),
            codec: .h264,
            to: outputURL
        ) { fraction in
            progress.record(fraction)
        }

        let exported = AVURLAsset(url: outputURL)
        let exportedDuration = try await exported.load(.duration).seconds
        XCTAssertEqual(exportedDuration, 2.0, accuracy: 0.1)
        let videoTracks = try await exported.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(videoTracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size, canvas)

        let generator = AVAssetImageGenerator(asset: exported)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (image, _) = try await generator.image(at: CMTime(seconds: 1.0, preferredTimescale: 600))
        let pixels = Self.pixels(of: image)

        let corner = pixels(CGPoint(x: 4, y: 4))
        XCTAssertLessThan(corner.red, 0.5, "canvas corner should be the ocean gradient, not the white source")
        XCTAssertGreaterThan(corner.blue, 0.4)

        let center = pixels(CGPoint(x: canvas.width / 2, y: canvas.height / 2))
        XCTAssertGreaterThan(center.red, 0.9)
        XCTAssertGreaterThan(center.green, 0.9)
        XCTAssertGreaterThan(center.blue, 0.9)

        let cameraRect = try XCTUnwrap(plan.cameraRect)
        let bubble = pixels(CGPoint(x: cameraRect.midX, y: canvas.height - cameraRect.midY))
        XCTAssertGreaterThan(bubble.red, 0.9)
        XCTAssertLessThan(bubble.green, 0.15)
        XCTAssertLessThan(bubble.blue, 0.15)

        XCTAssertFalse(progress.values.isEmpty)
    }

    private final class ProgressLog: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [Double] = []
        var values: [Double] { lock.lock(); defer { lock.unlock() }; return storage }
        func record(_ value: Double) { lock.lock(); storage.append(value); lock.unlock() }
    }

    private static func pixels(of image: CGImage) -> (CGPoint) -> (red: Double, green: Double, blue: Double) {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return { point in
            let x = min(max(Int(point.x), 0), width - 1)
            let y = min(max(Int(point.y), 0), height - 1)
            let offset = (y * width + x) * 4
            return (Double(data[offset]) / 255, Double(data[offset + 1]) / 255, Double(data[offset + 2]) / 255)
        }
    }

    private static func writeVideo(to url: URL, size: CGSize, frame: (Double) -> CIImage) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        for index in 0..<Int(duration * Double(frameRate)) {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try XCTUnwrap(adaptor.pixelBufferPool), &pixelBuffer)
            let buffer = try XCTUnwrap(pixelBuffer)
            context.render(frame(Double(index) / Double(frameRate)), to: buffer, bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: CMTimeScale(frameRate))))
        }
        input.markAsFinished()
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        finished.wait()
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
    }
}
