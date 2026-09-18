import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ScreenChest

final class BackgroundPainterTests: XCTestCase {
    func testEveryGradientRendersAtRequestedSize() {
        for preset in BackgroundPreset.gradients {
            let image = BackgroundPainter.render(preset, size: CGSize(width: 320, height: 180))
            XCTAssertEqual(image?.width, 320, preset.id)
            XCTAssertEqual(image?.height, 180, preset.id)
        }
    }

    func testGradientIDsAreUnique() {
        let ids = BackgroundPreset.gradients.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testUnknownPresetFallsBackToFirstGradient() {
        XCTAssertEqual(BackgroundPreset.named("does-not-exist").id, BackgroundPreset.gradients[0].id)
    }

    func testMissingWallpaperFileRendersFallbackColor() {
        let preset = BackgroundPreset.wallpaper(named: "Missing", url: URL(fileURLWithPath: "/nonexistent/missing.heic"))
        XCTAssertNotNil(BackgroundPainter.render(preset, size: CGSize(width: 64, height: 64)))
    }

    func testDumpPreviewsWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["SCREENCHEST_BACKGROUND_DUMP"] else { return }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for preset in BackgroundPreset.all {
            guard let image = BackgroundPainter.render(preset, size: CGSize(width: 480, height: 300)) else { continue }
            let url = folder.appendingPathComponent("\(preset.id.replacingOccurrences(of: ":", with: "-")).png")
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }
}
