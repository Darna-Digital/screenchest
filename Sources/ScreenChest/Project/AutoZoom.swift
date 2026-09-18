import Foundation

enum AutoZoom {
    static let leadIn: Double = 0.6
    static let hold: Double = 2.5
    static let mergeGap: Double = 1.5
    static let defaultScale: Double = 2.0
    static let minimumDuration: Double = 0.5

    static func generate(from mouse: MouseTrack, duration: Double) -> [ZoomSegment] {
        var segments: [ZoomSegment] = []
        for click in mouse.clicks.sorted(by: { $0.t < $1.t }) {
            guard click.t >= 0, click.t <= duration, (0...1).contains(click.x), (0...1).contains(click.y) else { continue }
            if let index = segments.indices.last, click.t <= segments[index].end + mergeGap {
                segments[index].end = min(duration, click.t + hold)
                continue
            }
            let start = max(0, click.t - leadIn)
            segments.append(ZoomSegment(
                id: UUID(),
                start: start,
                end: min(duration, click.t + hold),
                scale: defaultScale,
                anchor: NormalizedPoint(x: click.x, y: click.y),
                followsCursor: true
            ))
        }
        return segments.filter { $0.duration >= minimumDuration }
    }
}
