import XCTest
@testable import ScreenSail

final class MouseTrackTests: XCTestCase {
    func testEmptyTrackReturnsCenter() {
        XCTAssertEqual(MouseTrack.empty.position(at: 3).x, 0.5)
        XCTAssertEqual(MouseTrack.empty.position(at: 3).y, 0.5)
    }

    func testInterpolatesBetweenSamplesAndClampsOutside() {
        let track = MouseTrack(samples: [
            MouseSample(t: 1, x: 0, y: 0),
            MouseSample(t: 2, x: 1, y: 0.5),
            MouseSample(t: 4, x: 0, y: 1),
        ], clicks: [])
        XCTAssertEqual(track.position(at: 0).x, 0)
        XCTAssertEqual(track.position(at: 1.5).x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(track.position(at: 1.5).y, 0.25, accuracy: 1e-9)
        XCTAssertEqual(track.position(at: 3).x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(track.position(at: 10).y, 1)
    }
}
