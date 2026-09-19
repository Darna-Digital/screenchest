import XCTest
@testable import ScreenChest

final class ExportEstimateTests: XCTestCase {
    private let fullHD = CGSize(width: 1920, height: 1080)

    func testHEVCIsSmallerThanH264ForSameOutput() {
        let h264 = ExportEstimate.fileSizeBytes(canvas: fullHD, frameRate: 60, duration: 30, codec: .h264, hasAudio: false)
        let hevc = ExportEstimate.fileSizeBytes(canvas: fullHD, frameRate: 60, duration: 30, codec: .hevc, hasAudio: false)
        XCTAssertLessThan(hevc, h264)
    }

    func testSizeScalesWithDurationAndResolution() {
        let short = ExportEstimate.fileSizeBytes(canvas: fullHD, frameRate: 60, duration: 10, codec: .h264, hasAudio: false)
        let long = ExportEstimate.fileSizeBytes(canvas: fullHD, frameRate: 60, duration: 20, codec: .h264, hasAudio: false)
        XCTAssertEqual(long, short * 2)

        let hd = ExportEstimate.fileSizeBytes(canvas: CGSize(width: 1280, height: 720), frameRate: 60, duration: 10, codec: .h264, hasAudio: false)
        XCTAssertLessThan(hd, short)
    }

    func testAudioAddsItsBitrate() {
        let silent = ExportEstimate.fileSizeBytes(canvas: fullHD, frameRate: 60, duration: 10, codec: .h264, hasAudio: false)
        let withAudio = ExportEstimate.fileSizeBytes(canvas: fullHD, frameRate: 60, duration: 10, codec: .h264, hasAudio: true)
        XCTAssertEqual(withAudio - silent, Int64(ExportEstimate.audioBitsPerSecond * 10 / 8))
    }

    func testNegativeDurationEstimatesZero() {
        XCTAssertEqual(ExportEstimate.fileSizeBytes(canvas: fullHD, frameRate: 60, duration: -1, codec: .h264, hasAudio: true), 0)
    }

    func testLabelUsesMegabytes() {
        XCTAssertEqual(ExportEstimate.label(bytes: 45_000_000), "~45 MB")
    }
}
