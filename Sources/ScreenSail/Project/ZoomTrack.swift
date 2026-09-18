import Foundation

struct ZoomState: Equatable {
    var scale: Double
    var cx: Double
    var cy: Double

    static let identity = ZoomState(scale: 1, cx: 0.5, cy: 0.5)

    func clamped() -> ZoomState {
        let scale = max(1, self.scale)
        let half = 0.5 / scale
        return ZoomState(scale: scale, cx: min(max(cx, half), 1 - half), cy: min(max(cy, half), 1 - half))
    }
}

struct ZoomTrack: Equatable {
    let fps: Double
    let frames: [ZoomState]

    static let identity = ZoomTrack(fps: 60, frames: [.identity])

    func state(at time: Double) -> ZoomState {
        guard frames.count > 1 else { return frames.first ?? .identity }
        let position = max(0, time * fps)
        let index = Int(position)
        guard index < frames.count - 1 else { return frames[frames.count - 1] }
        let f = position - Double(index)
        let a = frames[index]
        let b = frames[index + 1]
        return ZoomState(
            scale: a.scale + (b.scale - a.scale) * f,
            cx: a.cx + (b.cx - a.cx) * f,
            cy: a.cy + (b.cy - a.cy) * f
        )
    }
}

enum ZoomTrackBuilder {
    static let fps: Double = 60
    static let smoothingWindow: Double = 0.4
    static let smoothingPasses = 3
    static let deadZoneFraction = 0.6

    static func build(segments: [ZoomSegment], mouse: MouseTrack, duration: Double) -> ZoomTrack {
        let sorted = segments.sorted { $0.start < $1.start }
        let frameCount = max(2, Int((duration * fps).rounded(.up)) + 1)
        var scales = [Double](repeating: 1, count: frameCount)
        var xs = [Double](repeating: 0.5, count: frameCount)
        var ys = [Double](repeating: 0.5, count: frameCount)

        for segment in sorted {
            let firstFrame = max(0, Int((segment.start * fps).rounded(.down)))
            let lastFrame = min(frameCount - 1, Int((segment.end * fps).rounded(.down)))
            guard firstFrame <= lastFrame else { continue }
            var center = ZoomState(scale: segment.scale, cx: segment.anchor.x, cy: segment.anchor.y).clamped()
            let deadZone = (0.5 / segment.scale) * deadZoneFraction
            for frame in firstFrame...lastFrame {
                if segment.followsCursor {
                    let cursor = mouse.position(at: Double(frame) / fps)
                    center.cx = follow(center: center.cx, target: cursor.x, deadZone: deadZone)
                    center.cy = follow(center: center.cy, target: cursor.y, deadZone: deadZone)
                    center = center.clamped()
                }
                scales[frame] = center.scale
                xs[frame] = center.cx
                ys[frame] = center.cy
            }
        }

        let window = max(1, Int(smoothingWindow * fps) | 1)
        for _ in 0..<smoothingPasses {
            scales = movingAverage(scales, window: window)
            xs = movingAverage(xs, window: window)
            ys = movingAverage(ys, window: window)
        }

        var frames: [ZoomState] = []
        frames.reserveCapacity(frameCount)
        for i in 0..<frameCount {
            frames.append(ZoomState(scale: scales[i], cx: xs[i], cy: ys[i]).clamped())
        }
        return ZoomTrack(fps: fps, frames: frames)
    }

    private static func follow(center: Double, target: Double, deadZone: Double) -> Double {
        let delta = target - center
        if delta > deadZone { return center + (delta - deadZone) }
        if delta < -deadZone { return center + (delta + deadZone) }
        return center
    }

    private static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard values.count > 1, window > 1 else { return values }
        let half = window / 2
        let count = values.count
        var prefix = [Double](repeating: 0, count: count + 1)
        for i in 0..<count { prefix[i + 1] = prefix[i] + values[i] }
        var result = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let lower = i - half
            let upper = i + half
            var sum = prefix[min(count, upper + 1)] - prefix[max(0, lower)]
            if lower < 0 { sum += values[0] * Double(-lower) }
            if upper > count - 1 { sum += values[count - 1] * Double(upper - (count - 1)) }
            result[i] = sum / Double(window)
        }
        return result
    }
}
