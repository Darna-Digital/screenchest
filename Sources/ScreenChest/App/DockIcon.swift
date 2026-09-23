import AppKit

// macOS 26 only shows an Icon Composer icon's dark rendering under the "Dark"
// icon style, so the dock tile is swapped by hand to follow the appearance.
enum DockIcon {
    @MainActor
    static func follow(_ appearance: NSAppearance) {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let resource = isDark ? "ScreenChest-dark" : "ScreenChest"
        guard let url = Bundle.main.url(forResource: resource, withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { app, _ in
            MainActor.assumeIsolated { DockIcon.follow(app.effectiveAppearance) }
        }
    }
}
