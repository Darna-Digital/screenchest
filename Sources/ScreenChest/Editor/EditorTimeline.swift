import AppKit
import SwiftUI

private extension Color {
    static let trimmedOut = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return .black.withAlphaComponent(isDark ? 0.35 : 0.06)
    })
}

struct TimeScale {
    let pixelsPerSecond: CGFloat
    let width: CGFloat

    func x(_ time: Double) -> CGFloat { CGFloat(time) * pixelsPerSecond }
    func time(_ x: CGFloat) -> Double { Double(min(max(x, 0), width) / pixelsPerSecond) }
}

struct EditorTimeline: View {
    static let rulerHeight: CGFloat = 22
    static let clipRowHeight: CGFloat = 40
    static let zoomRowHeight: CGFloat = 30
    static let rowSpacing: CGFloat = 6
    static let height = rulerHeight + rowSpacing + clipRowHeight + rowSpacing + zoomRowHeight
    static let gripWidth: CGFloat = 10
    static let coordinateSpace = "timeline"

    let model: EditorModel

    var body: some View {
        GeometryReader { geometry in
            let scale = TimeScale(pixelsPerSecond: geometry.size.width / max(model.duration, 0.001), width: geometry.size.width)
            ZStack(alignment: .topLeading) {
                VStack(spacing: EditorTimeline.rowSpacing) {
                    RulerView(model: model, scale: scale)
                        .frame(height: EditorTimeline.rulerHeight)
                    ClipRow(model: model, scale: scale)
                        .frame(height: EditorTimeline.clipRowHeight)
                    ZoomRow(model: model, scale: scale)
                        .frame(height: EditorTimeline.zoomRowHeight)
                }
                PlayheadLayer(model: model, scale: scale)
            }
            .coordinateSpace(name: EditorTimeline.coordinateSpace)
        }
        .frame(height: EditorTimeline.height)
    }
}

private struct RulerView: View {
    static let intervals: [Double] = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600]
    static let minimumLabelSpacing: CGFloat = 72

    let model: EditorModel
    let scale: TimeScale

    var body: some View {
        let duration = model.duration
        Canvas { context, size in
            let interval = RulerView.intervals.first { scale.x($0) >= RulerView.minimumLabelSpacing } ?? RulerView.intervals.last!
            var minor = Path()
            var time = 0.0
            while time <= duration + 1e-9 {
                let x = scale.x(time)
                minor.move(to: CGPoint(x: x, y: size.height))
                minor.addLine(to: CGPoint(x: x, y: size.height - 4))
                time += interval / 4
            }
            context.stroke(minor, with: .color(.secondary.opacity(0.4)), lineWidth: 1)

            var major = Path()
            time = 0
            while time <= duration + 1e-9 {
                let x = scale.x(time)
                major.move(to: CGPoint(x: x, y: size.height))
                major.addLine(to: CGPoint(x: x, y: size.height - 8))
                context.draw(
                    Text(TimeFormatting.clock(time)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary),
                    at: CGPoint(x: x + 3, y: 0),
                    anchor: .topLeading
                )
                time += interval
            }
            context.stroke(major, with: .color(.secondary), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                .onChanged { value in model.seek(to: scale.time(value.location.x)) }
        )
    }
}

private struct ClipRow: View {
    let model: EditorModel
    let scale: TimeScale

    var body: some View {
        let start = model.edits.trimStart
        let end = model.edits.trimEnd
        let x = scale.x(start)
        let width = max(EditorTimeline.gripWidth * 2, scale.x(end) - x)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Rectangle().fill(Color.trimmedOut))
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
                if width > 70 {
                    Text(TimeFormatting.precise(end - start))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 0) {
                    EdgeGrip(time: start, prominent: true, scale: scale) { model.setTrimStart($0) }
                    Spacer(minLength: 0)
                    EdgeGrip(time: end, prominent: true, scale: scale) { model.setTrimEnd($0) }
                }
            }
            .frame(width: width, height: EditorTimeline.clipRowHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                    .onChanged { value in model.seek(to: scale.time(value.location.x)) }
            )
            .offset(x: x)
            ClickMarkers(clicks: model.mouse.clicks, pixelsPerSecond: scale.pixelsPerSecond)
                .equatable()
                .frame(height: 5)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct ClickMarkers: View, Equatable {
    let clicks: [MouseClick]
    let pixelsPerSecond: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for click in clicks {
                let x = CGFloat(click.t) * pixelsPerSecond
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(path, with: .color(.secondary.opacity(0.7)), lineWidth: 1)
        }
    }
}

private struct ZoomRow: View {
    let model: EditorModel
    let scale: TimeScale
    @State private var pointerTime: Double = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                        .onChanged { value in
                            model.selectedZoomID = nil
                            model.seek(to: scale.time(value.location.x))
                        }
                )
                .contextMenu {
                    Button("Add Zoom Here") { model.addZoom(at: pointerTime) }
                }
            ForEach(model.sortedZooms) { segment in
                ZoomBlock(model: model, segment: segment, isSelected: segment.id == model.selectedZoomID, scale: scale)
            }
            Rectangle()
                .fill(Color.trimmedOut)
                .frame(width: max(0, scale.x(model.edits.trimStart)), height: EditorTimeline.zoomRowHeight)
                .allowsHitTesting(false)
            Rectangle()
                .fill(Color.trimmedOut)
                .frame(width: max(0, scale.width - scale.x(model.edits.trimEnd)), height: EditorTimeline.zoomRowHeight)
                .offset(x: scale.x(model.edits.trimEnd))
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onContinuousHover(coordinateSpace: .local) { phase in
            if case .active(let location) = phase {
                pointerTime = scale.time(location.x)
            }
        }
    }
}

private struct ZoomBlock: View {
    let model: EditorModel
    let segment: ZoomSegment
    let isSelected: Bool
    let scale: TimeScale
    @State private var dragOriginStart: Double?

    var body: some View {
        let x = scale.x(segment.start)
        let width = max(EditorTimeline.gripWidth * 2, scale.x(segment.end) - x)
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentColor.opacity(isSelected ? 0.85 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(isSelected ? Color.white : Color.accentColor, lineWidth: isSelected ? 2 : 1)
                )
            if width > 44 {
                Text(String(format: "%.1f×", segment.scale))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            HStack(spacing: 0) {
                EdgeGrip(time: segment.start, prominent: isSelected, scale: scale) { time in
                    model.selectedZoomID = segment.id
                    model.resizeZoom(id: segment.id, edge: .leading, to: time)
                }
                Spacer(minLength: 0)
                EdgeGrip(time: segment.end, prominent: isSelected, scale: scale) { time in
                    model.selectedZoomID = segment.id
                    model.resizeZoom(id: segment.id, edge: .trailing, to: time)
                }
            }
        }
        .frame(width: width, height: EditorTimeline.zoomRowHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                .onChanged { value in
                    if dragOriginStart == nil {
                        dragOriginStart = segment.start
                        model.selectedZoomID = segment.id
                    }
                    let delta = Double(value.translation.width / scale.pixelsPerSecond)
                    model.moveZoom(id: segment.id, toStart: (dragOriginStart ?? segment.start) + delta)
                }
                .onEnded { _ in dragOriginStart = nil }
        )
        .contextMenu {
            Button("Delete Zoom") { model.deleteZoom(id: segment.id) }
        }
        .offset(x: x)
    }
}

private struct EdgeGrip: View {
    let time: Double
    let prominent: Bool
    let scale: TimeScale
    let onChange: (Double) -> Void
    @State private var origin: Double?

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: EditorTimeline.gripWidth)
            .overlay {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(prominent ? 0.7 : 0.25))
                    .frame(width: 3, height: 14)
            }
            .contentShape(Rectangle())
            .pointerStyle(.columnResize(directions: .all))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                    .onChanged { value in
                        if origin == nil {
                            origin = time
                        }
                        onChange((origin ?? time) + Double(value.translation.width / scale.pixelsPerSecond))
                    }
                    .onEnded { _ in origin = nil }
            )
    }
}

private struct PlayheadLayer: View {
    let model: EditorModel
    let scale: TimeScale

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.red)
                .frame(width: 2)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9))
                .foregroundStyle(.red)
                .offset(y: 1)
        }
        .frame(width: 12, height: EditorTimeline.height)
        .offset(x: scale.x(model.currentTime) - 6)
        .allowsHitTesting(false)
    }
}
