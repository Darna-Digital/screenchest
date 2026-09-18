import XCTest
@testable import ScreenSail

final class RenderPlanTests: XCTestCase {
    private func project(width: Int, height: Int, camera: Bool) -> Project {
        var edits = Edits.initial(duration: 10, zooms: [], hasCamera: camera)
        edits.padding = 0.1
        return Project(
            name: "Test",
            createdAt: Date(),
            recording: RecordingInfo(
                screenFile: "screen.mov",
                cameraFile: camera ? "camera.mov" : nil,
                mouseFile: "mouse.json",
                audioTracks: [.microphone],
                pixelWidth: width,
                pixelHeight: height,
                duration: 10,
                sourceName: "Test"
            ),
            edits: edits
        )
    }

    func testContentRectIsCenteredAndKeepsSourceAspect() {
        let plan = RenderPlan.make(project: project(width: 3456, height: 2234, camera: false), mouse: .empty, canvasSize: CGSize(width: 1920, height: 1242), hasCamera: false)
        XCTAssertEqual(plan.contentRect.midX, 960, accuracy: 1e-6)
        XCTAssertEqual(plan.contentRect.midY, 621, accuracy: 1e-6)
        XCTAssertEqual(plan.contentRect.width / plan.contentRect.height, 3456.0 / 2234.0, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(plan.contentRect.maxX, 1920 - 124.2 + 1e-6)
        XCTAssertNil(plan.cameraRect)
    }

    func testCameraRectStaysInsideCanvasForEveryCorner() throws {
        for corner in CameraStyle.Corner.allCases {
            var project = project(width: 1920, height: 1080, camera: true)
            project.edits.camera.corner = corner
            let plan = RenderPlan.make(project: project, mouse: .empty, canvasSize: CGSize(width: 1920, height: 1080), hasCamera: true)
            let rect = try XCTUnwrap(plan.cameraRect)
            XCTAssertTrue(plan.canvasRect.contains(rect), "\(corner) placed camera outside the canvas")
            XCTAssertEqual(rect.width, rect.height)
        }
    }

    func testCanvasSizesAreEvenAndRespectResolutionCaps() {
        let source = CGSize(width: 3457, height: 2235)
        XCTAssertEqual(RenderPlan.canvasSize(for: source, resolution: .source), CGSize(width: 3456, height: 2234))
        let capped = RenderPlan.canvasSize(for: source, resolution: .p1080)
        XCTAssertEqual(capped.height, 1080)
        XCTAssertEqual(Int(capped.width) % 2, 0)
        XCTAssertEqual(RenderPlan.canvasSize(for: CGSize(width: 1280, height: 720), resolution: .p1080), CGSize(width: 1280, height: 720))
        XCTAssertLessThanOrEqual(RenderPlan.previewCanvasSize(for: CGSize(width: 5120, height: 2880)).height, CGFloat(RenderPlan.previewMaxHeight))
    }

    func testEvenSizeRoundsDownToEvenAndNeverBelowTwo() {
        XCTAssertEqual(CaptureTarget.evenSize(CGSize(width: 1001.9, height: 3)), CGSize(width: 1000, height: 2))
        XCTAssertEqual(CaptureTarget.evenSize(CGSize(width: 1, height: 0)), CGSize(width: 2, height: 2))
    }
}
