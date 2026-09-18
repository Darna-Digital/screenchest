import SwiftUI

struct EditorTimeline: View {
    static let handleWidth: CGFloat = 10
    static let clickMarkerY: CGFloat = 12
    static let segmentTop: CGFloat = 26
    static let segmentHeight: CGFloat = 40
    static let coordinateSpace = "timeline"

    let model: EditorModel
    @State private var dragOriginStart: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let duration = max(model.duration, 0.001)
            let position = { (time: Double) -> CGFloat in CGFloat(time / duration) * width }
            let time = { (x: CGFloat) -> Double in Double(min(max(x, 0), width) / width) * duration }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                            .onChanged { value in
                                model.selectedZoomID = nil
                                model.seek(to: time(value.location.x))
                            }
                    )

                ForEach(Array(model.mouse.clicks.enumerated()), id: \.offset) { _, click in
                    Circle()
                        .fill(.secondary.opacity(0.6))
                        .frame(width: 5, height: 5)
                        .position(x: position(click.t), y: EditorTimeline.clickMarkerY)
                        .allowsHitTesting(false)
                }

                ForEach(model.sortedZooms) { segment in
                    ZoomSegmentView(segment: segment, isSelected: segment.id == model.selectedZoomID)
                        .frame(width: max(8, position(segment.end) - position(segment.start)), height: EditorTimeline.segmentHeight)
                        .offset(x: position(segment.start), y: EditorTimeline.segmentTop)
                        .onTapGesture { model.selectedZoomID = segment.id }
                        .gesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                                .onChanged { value in
                                    if dragOriginStart == nil {
                                        dragOriginStart = segment.start
                                        model.selectedZoomID = segment.id
                                    }
                                    let delta = Double(value.translation.width / width) * duration
                                    model.moveZoom(id: segment.id, toStart: (dragOriginStart ?? segment.start) + delta)
                                }
                                .onEnded { _ in dragOriginStart = nil }
                        )
                }

                Rectangle()
                    .fill(.black.opacity(0.4))
                    .frame(width: max(0, position(model.edits.trimStart)), height: height)
                    .allowsHitTesting(false)
                Rectangle()
                    .fill(.black.opacity(0.4))
                    .frame(width: max(0, width - position(model.edits.trimEnd)), height: height)
                    .offset(x: position(model.edits.trimEnd))
                    .allowsHitTesting(false)

                TrimHandle()
                    .frame(width: EditorTimeline.handleWidth, height: height)
                    .offset(x: position(model.edits.trimStart) - EditorTimeline.handleWidth / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                            .onChanged { value in model.setTrimStart(time(value.location.x)) }
                    )
                TrimHandle()
                    .frame(width: EditorTimeline.handleWidth, height: height)
                    .offset(x: position(model.edits.trimEnd) - EditorTimeline.handleWidth / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorTimeline.coordinateSpace))
                            .onChanged { value in model.setTrimEnd(time(value.location.x)) }
                    )

                Rectangle()
                    .fill(.red)
                    .frame(width: 2, height: height)
                    .offset(x: position(model.currentTime) - 1)
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: EditorTimeline.coordinateSpace)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct ZoomSegmentView: View {
    let segment: ZoomSegment
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.accentColor.opacity(isSelected ? 0.85 : 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.white : Color.accentColor, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .leading) {
                Text(String(format: "%.1f×", segment.scale))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.leading, 6)
                    .lineLimit(1)
            }
    }
}

private struct TrimHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.primary.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 2, height: 16)
            )
    }
}
