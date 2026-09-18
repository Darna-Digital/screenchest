import XCTest
@testable import ScreenSail

final class ProjectStoreTests: XCTestCase {
    func testProjectAndMouseTrackRoundTrip() throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenSailTests-\(UUID().uuidString)")
            .appendingPathExtension(ProjectStore.packageExtension)
        try ProjectStore.createPackage(at: packageURL)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let zoom = ZoomSegment(id: UUID(), start: 1, end: 4, scale: 2.5, anchor: NormalizedPoint(x: 0.2, y: 0.8), followsCursor: false)
        let project = Project(
            name: "Round trip",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            recording: RecordingInfo(
                screenFile: "screen.mov",
                cameraFile: "camera.mov",
                mouseFile: "mouse.json",
                audioTracks: [.microphone, .systemAudio],
                pixelWidth: 1920,
                pixelHeight: 1080,
                duration: 12.5,
                sourceName: "Main Display"
            ),
            edits: Edits.initial(duration: 12.5, zooms: [zoom], hasCamera: true)
        )
        try ProjectStore.save(project, to: packageURL)
        XCTAssertEqual(try ProjectStore.load(from: packageURL), project)

        let mouse = MouseTrack(samples: [MouseSample(t: 0.5, x: 0.1, y: 0.2)], clicks: [MouseClick(t: 0.7, x: 0.3, y: 0.4)])
        try ProjectStore.saveMouseTrack(mouse, to: packageURL)
        XCTAssertEqual(ProjectStore.loadMouseTrack(from: packageURL, fileName: "mouse.json"), mouse)
        XCTAssertEqual(ProjectStore.loadMouseTrack(from: packageURL, fileName: "missing.json"), .empty)
    }

    func testTimeFormatting() {
        XCTAssertEqual(TimeFormatting.clock(65), "01:05")
        XCTAssertEqual(TimeFormatting.precise(65.26), "01:05.3")
        XCTAssertEqual(TimeFormatting.precise(-2), "00:00.0")
    }
}
