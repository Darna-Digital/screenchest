import AppKit
import ScreenCaptureKit

struct CaptureTarget: Identifiable, Hashable {
    enum Kind { case display, window }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let frame: CGRect
    let backingScale: CGFloat
    private let display: SCDisplay?
    private let window: SCWindow?

    static func == (lhs: CaptureTarget, rhs: CaptureTarget) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(display: SCDisplay, index: Int) {
        id = "display-\(display.displayID)"
        kind = .display
        title = index == 0 ? "Main Display" : "Display \(index + 1)"
        subtitle = "\(display.width) × \(display.height)"
        frame = display.frame
        backingScale = CaptureTarget.backingScale(forDisplayID: display.displayID)
        self.display = display
        window = nil
    }

    init(window: SCWindow, scale: CGFloat) {
        id = "window-\(window.windowID)"
        kind = .window
        title = window.title ?? "Untitled"
        subtitle = window.owningApplication?.applicationName ?? ""
        frame = window.frame
        backingScale = scale
        display = nil
        self.window = window
    }

    var pixelSize: CGSize {
        CaptureTarget.evenSize(CGSize(width: frame.width * backingScale, height: frame.height * backingScale))
    }

    func currentFrame() -> CGRect {
        guard let window else { return frame }
        let options = CGWindowListOption(arrayLiteral: .optionIncludingWindow)
        guard let list = CGWindowListCopyWindowInfo(options, window.windowID) as? [[String: Any]],
              let boundsDictionary = list.first?[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary) else { return frame }
        return bounds
    }

    func makeContentFilter(excluding applications: [SCRunningApplication]) -> SCContentFilter {
        if let window {
            return SCContentFilter(desktopIndependentWindow: window)
        }
        return SCContentFilter(display: display!, excludingApplications: applications, exceptingWindows: [])
    }

    static func evenSize(_ size: CGSize) -> CGSize {
        let width = max(2, Int(size.width.rounded(.down)) & ~1)
        let height = max(2, Int(size.height.rounded(.down)) & ~1)
        return CGSize(width: width, height: height)
    }

    static func backingScale(forDisplayID displayID: CGDirectDisplayID) -> CGFloat {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let screen = NSScreen.screens.first { ($0.deviceDescription[key] as? NSNumber)?.uint32Value == displayID }
        return screen?.backingScaleFactor ?? 2
    }
}

struct ShareableContent {
    var displays: [CaptureTarget]
    var windows: [CaptureTarget]
    var ownApplications: [SCRunningApplication]

    static func load() async throws -> ShareableContent {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownApplications = content.applications.filter { $0.processID == ownPID }
        let displays = content.displays.enumerated().map { CaptureTarget(display: $1, index: $0) }
        let windows = content.windows
            .filter { window in
                window.windowLayer == 0
                    && window.isOnScreen
                    && window.frame.width >= 120
                    && window.frame.height >= 80
                    && !(window.title ?? "").isEmpty
                    && window.owningApplication?.processID != ownPID
            }
            .map { window -> CaptureTarget in
                let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
                let hostDisplay = content.displays.first { $0.frame.contains(center) } ?? content.displays.first
                let scale = hostDisplay.map { CaptureTarget.backingScale(forDisplayID: $0.displayID) } ?? 2
                return CaptureTarget(window: window, scale: scale)
            }
        return ShareableContent(displays: displays, windows: windows, ownApplications: ownApplications)
    }
}
