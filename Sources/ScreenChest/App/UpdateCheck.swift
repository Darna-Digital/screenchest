import AppKit
import Sparkle

@MainActor
final class UpdateCheck: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateCheck()

    /// `defaults write com.darnadigital.screenchest update.feedURL file:///tmp/appcast.xml`
    private static let feedOverrideKey = "update.feedURL"

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func start() {
        guard isBundled else { return }
        controller.startUpdater()
    }

    func checkByHand() {
        guard isBundled else { return }
        controller.checkForUpdates(nil)
    }

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: Self.feedOverrideKey)
    }
}
