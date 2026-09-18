import XCTest
@testable import ScreenSail

final class AutoZoomTests: XCTestCase {
    private func track(clicks: [(Double, Double, Double)]) -> MouseTrack {
        MouseTrack(samples: [], clicks: clicks.map { MouseClick(t: $0.0, x: $0.1, y: $0.2) })
    }

    func testNoClicksProducesNoZooms() {
        XCTAssertTrue(AutoZoom.generate(from: .empty, duration: 30).isEmpty)
    }

    func testSingleClickCreatesLeadInAndHold() {
        let zooms = AutoZoom.generate(from: track(clicks: [(5, 0.3, 0.4)]), duration: 30)
        XCTAssertEqual(zooms.count, 1)
        XCTAssertEqual(zooms[0].start, 5 - AutoZoom.leadIn, accuracy: 1e-9)
        XCTAssertEqual(zooms[0].end, 5 + AutoZoom.hold, accuracy: 1e-9)
        XCTAssertEqual(zooms[0].anchor.x, 0.3)
        XCTAssertEqual(zooms[0].anchor.y, 0.4)
        XCTAssertTrue(zooms[0].followsCursor)
    }

    func testNearbyClicksMergeIntoOneSegment() {
        let zooms = AutoZoom.generate(from: track(clicks: [(5, 0.3, 0.4), (6, 0.6, 0.6), (7.5, 0.2, 0.2)]), duration: 30)
        XCTAssertEqual(zooms.count, 1)
        XCTAssertEqual(zooms[0].end, 7.5 + AutoZoom.hold, accuracy: 1e-9)
    }

    func testDistantClicksNeverOverlap() {
        let zooms = AutoZoom.generate(from: track(clicks: [(5, 0.3, 0.4), (12, 0.6, 0.6), (20, 0.2, 0.2)]), duration: 30)
        XCTAssertEqual(zooms.count, 3)
        for pair in zip(zooms, zooms.dropFirst()) {
            XCTAssertLessThan(pair.0.end, pair.1.start)
        }
    }

    func testClicksOutsideRegionAndDurationAreIgnored() {
        let zooms = AutoZoom.generate(from: track(clicks: [(2, 1.4, 0.5), (4, 0.5, -0.1), (40, 0.5, 0.5)]), duration: 30)
        XCTAssertTrue(zooms.isEmpty)
    }

    func testSegmentsClampToRecordingBounds() {
        let late = AutoZoom.generate(from: track(clicks: [(29.9, 0.5, 0.5)]), duration: 30)
        XCTAssertEqual(late.count, 1)
        XCTAssertEqual(late[0].start, 29.9 - AutoZoom.leadIn, accuracy: 1e-9)
        XCTAssertEqual(late[0].end, 30, accuracy: 1e-9)
        let early = AutoZoom.generate(from: track(clicks: [(0.2, 0.5, 0.5)]), duration: 30)
        XCTAssertEqual(early.count, 1)
        XCTAssertEqual(early[0].start, 0)
    }

    func testTinyRecordingsProduceNoZooms() {
        XCTAssertTrue(AutoZoom.generate(from: track(clicks: [(0.1, 0.5, 0.5)]), duration: 0.3).isEmpty)
    }
}
