import XCTest
@testable import ScreenChest

final class ZoomTrackTests: XCTestCase {
    private func assertValid(_ state: ZoomState, file: StaticString = #filePath, line: UInt = #line) {
        let half = 0.5 / state.scale
        XCTAssertGreaterThanOrEqual(state.scale, 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(state.cx - half, -1e-9, file: file, line: line)
        XCTAssertLessThanOrEqual(state.cx + half, 1 + 1e-9, file: file, line: line)
        XCTAssertGreaterThanOrEqual(state.cy - half, -1e-9, file: file, line: line)
        XCTAssertLessThanOrEqual(state.cy + half, 1 + 1e-9, file: file, line: line)
    }

    func testEmptySegmentsStayAtIdentity() {
        let track = ZoomTrackBuilder.build(segments: [], mouse: .empty, duration: 5)
        for time in stride(from: 0.0, through: 5.0, by: 0.25) {
            XCTAssertEqual(track.state(at: time), .identity)
        }
    }

    func testSegmentReachesTargetScaleAndEasesInAndOut() {
        let segment = ZoomSegment(id: UUID(), start: 4, end: 8, scale: 2, anchor: NormalizedPoint(x: 0.3, y: 0.3), followsCursor: false)
        let track = ZoomTrackBuilder.build(segments: [segment], mouse: .empty, duration: 12)
        XCTAssertEqual(track.state(at: 1).scale, 1, accuracy: 1e-9)
        XCTAssertEqual(track.state(at: 6).scale, 2, accuracy: 1e-6)
        XCTAssertEqual(track.state(at: 6).cx, 0.3, accuracy: 1e-6)
        XCTAssertEqual(track.state(at: 11).scale, 1, accuracy: 1e-9)
        let entering = track.state(at: 4).scale
        XCTAssertGreaterThan(entering, 1)
        XCTAssertLessThan(entering, 2)
        var previous = track.state(at: 3).scale
        for time in stride(from: 3.0, through: 6.0, by: 1.0 / 60.0) {
            let scale = track.state(at: time).scale
            XCTAssertGreaterThanOrEqual(scale, previous - 1e-9)
            previous = scale
        }
    }

    func testEveryFrameKeepsViewportInsideSource() {
        let samples = stride(from: 0.0, through: 20.0, by: 1.0 / 60.0).map { t in
            MouseSample(t: t, x: 0.5 + 0.6 * sin(t), y: 0.5 + 0.6 * cos(t * 1.3))
        }
        let mouse = MouseTrack(samples: samples, clicks: [])
        let segments = [
            ZoomSegment(id: UUID(), start: 1, end: 6, scale: 2.5, anchor: NormalizedPoint(x: 0.05, y: 0.95), followsCursor: true),
            ZoomSegment(id: UUID(), start: 6, end: 12, scale: 1.5, anchor: NormalizedPoint(x: 0.9, y: 0.1), followsCursor: true),
            ZoomSegment(id: UUID(), start: 14, end: 19, scale: 4, anchor: NormalizedPoint(x: 0.5, y: 0.5), followsCursor: false),
        ]
        let track = ZoomTrackBuilder.build(segments: segments, mouse: mouse, duration: 20)
        for frame in track.frames { assertValid(frame) }
        for time in stride(from: 0.0, through: 20.0, by: 0.01) { assertValid(track.state(at: time)) }
    }

    func testFollowingCursorMovesCenterWhenCursorLeavesDeadZone() {
        let samples = stride(from: 0.0, through: 10.0, by: 1.0 / 60.0).map { t in
            MouseSample(t: t, x: t < 5 ? 0.5 : 0.9, y: 0.5)
        }
        let mouse = MouseTrack(samples: samples, clicks: [])
        let segment = ZoomSegment(id: UUID(), start: 2, end: 9, scale: 2, anchor: .center, followsCursor: true)
        let track = ZoomTrackBuilder.build(segments: [segment], mouse: mouse, duration: 10)
        XCTAssertEqual(track.state(at: 4).cx, 0.5, accuracy: 1e-6)
        XCTAssertGreaterThan(track.state(at: 7).cx, 0.6)
        XCTAssertLessThanOrEqual(track.state(at: 7).cx, 0.75 + 1e-9)
    }

    func testStateLookupClampsToTrackBounds() {
        let track = ZoomTrack(fps: 60, frames: [ZoomState(scale: 1, cx: 0.5, cy: 0.5), ZoomState(scale: 2, cx: 0.5, cy: 0.5)])
        XCTAssertEqual(track.state(at: -5).scale, 1)
        XCTAssertEqual(track.state(at: 100).scale, 2)
        XCTAssertEqual(track.state(at: 0.5 / 60).scale, 1.5, accuracy: 1e-9)
    }
}
