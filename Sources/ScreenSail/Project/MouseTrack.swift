import Foundation

struct MouseSample: Codable, Equatable {
    var t: Double
    var x: Double
    var y: Double
}

struct MouseClick: Codable, Equatable {
    var t: Double
    var x: Double
    var y: Double
}

struct MouseTrack: Codable, Equatable {
    var samples: [MouseSample]
    var clicks: [MouseClick]

    static let empty = MouseTrack(samples: [], clicks: [])

    func position(at time: Double) -> NormalizedPoint {
        guard let first = samples.first else { return .center }
        if time <= first.t { return NormalizedPoint(x: first.x, y: first.y) }
        guard let last = samples.last, time < last.t else {
            let end = samples[samples.count - 1]
            return NormalizedPoint(x: end.x, y: end.y)
        }
        var low = 0
        var high = samples.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if samples[mid].t <= time { low = mid } else { high = mid }
        }
        let a = samples[low]
        let b = samples[high]
        let span = b.t - a.t
        let f = span > 0 ? (time - a.t) / span : 0
        return NormalizedPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }
}
