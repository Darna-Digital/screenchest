import AppKit
import CoreMedia

final class MouseTracker {
    static let pollsPerSecond = 120.0
    static let samplesPerSecond = 60.0
    static let frameRefreshInterval = 60

    private struct RawSample {
        let hostTime: Double
        let x: Double
        let y: Double
    }

    private let queue = DispatchQueue(label: "screenchest.mouse", qos: .userInitiated)
    private let frameProvider: () -> CGRect
    private var timer: DispatchSourceTimer?
    private var frame: CGRect
    private var samples: [RawSample] = []
    private var clicks: [RawSample] = []
    private var wasButtonDown = false
    private var lastSampleHostTime = -Double.infinity
    private var pollCount = 0

    init(frameProvider: @escaping () -> CGRect) {
        self.frameProvider = frameProvider
        frame = frameProvider()
    }

    func start() {
        queue.sync {
            guard timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: 1.0 / MouseTracker.pollsPerSecond, leeway: .milliseconds(1))
            timer.setEventHandler { [weak self] in self?.poll() }
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
        }
    }

    func track(startingAt startHostTime: Double) -> MouseTrack {
        queue.sync {
            MouseTrack(
                samples: samples.map { MouseSample(t: $0.hostTime - startHostTime, x: $0.x, y: $0.y) },
                clicks: clicks.map { MouseClick(t: $0.hostTime - startHostTime, x: $0.x, y: $0.y) }
            )
        }
    }

    static func hostSeconds() -> Double {
        CMClockGetTime(CMClockGetHostTimeClock()).seconds
    }

    private func poll() {
        pollCount += 1
        if pollCount % MouseTracker.frameRefreshInterval == 0 {
            let refreshed = frameProvider()
            if refreshed.width > 0, refreshed.height > 0 { frame = refreshed }
        }
        guard frame.width > 0, frame.height > 0, let location = CGEvent(source: nil)?.location else { return }
        let now = MouseTracker.hostSeconds()
        let sample = RawSample(
            hostTime: now,
            x: (location.x - frame.minX) / frame.width,
            y: (location.y - frame.minY) / frame.height
        )
        let isButtonDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        if isButtonDown, !wasButtonDown {
            clicks.append(sample)
        }
        wasButtonDown = isButtonDown
        if now - lastSampleHostTime >= 1.0 / MouseTracker.samplesPerSecond {
            samples.append(sample)
            lastSampleHostTime = now
        }
    }
}
