import XCTest
@testable import ScreenChest

final class ProjectStoreTests: XCTestCase {
    func testProjectAndMouseTrackRoundTrip() throws {
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenChestTests-\(UUID().uuidString)")
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

    func testEditsDecodeWithoutTrimKeys() throws {
        let json = """
        {"backgroundPresetID":"ocean","camera":{"corner":"bottomRight","enabled":false,"mirrored":true,"shape":"circle","size":0.22},
         "cornerRadius":0.02,"microphoneVolume":1,"output":{"codec":"h264","resolution":"source"},"padding":0.06,"shadow":true,
         "systemAudioVolume":1,"zooms":[],"clips":[{"id":"5AE554C6-08F9-432A-8590-262B1BFD9579","start":1.5,"end":8}]}
        """
        var edits = try JSONDecoder().decode(Edits.self, from: Data(json.utf8))
        XCTAssertEqual(edits.trimStart, 1.5)
        XCTAssertEqual(edits.trimEnd, 8)

        let bare = json.replacingOccurrences(of: ",\"clips\":[{\"id\":\"5AE554C6-08F9-432A-8590-262B1BFD9579\",\"start\":1.5,\"end\":8}]", with: "")
        edits = try JSONDecoder().decode(Edits.self, from: Data(bare.utf8))
        edits.clampTrim(to: 12)
        XCTAssertEqual(edits.trimStart, 0)
        XCTAssertEqual(edits.trimEnd, 12)
    }

    func testTimeFormatting() {
        XCTAssertEqual(TimeFormatting.clock(65), "01:05")
        XCTAssertEqual(TimeFormatting.precise(65.26), "01:05.3")
        XCTAssertEqual(TimeFormatting.precise(-2), "00:00.0")
    }
}
