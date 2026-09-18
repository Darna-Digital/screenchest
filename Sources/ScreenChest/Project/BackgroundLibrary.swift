import AppKit
import Foundation

enum BackgroundLibrary {
    static let systemPicturesURL = URL(fileURLWithPath: "/System/Library/Desktop Pictures", isDirectory: true)
    static let imageExtensions: Set<String> = ["heic", "jpg", "jpeg", "png", "tiff"]

    static let wallpapers: [BackgroundPreset] = desktopPicture() + systemWallpapers()

    private static func desktopPicture() -> [BackgroundPreset] {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              isImage(url), FileManager.default.isReadableFile(atPath: url.path) else { return [] }
        return [BackgroundPreset.desktopPicture(url: url)]
    }

    private static func systemWallpapers() -> [BackgroundPreset] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: systemPicturesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return items
            .filter(isImage)
            .map { BackgroundPreset.wallpaper(named: $0.deletingPathExtension().lastPathComponent, url: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func isImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }
}
