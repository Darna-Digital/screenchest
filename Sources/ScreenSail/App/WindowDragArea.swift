import AppKit
import SwiftUI

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
    }
}

struct MovesWindowOnDrag: ViewModifier {
    static let minimumDistance: CGFloat = 4

    @State private var window: NSWindow?
    @State private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    func body(content: Content) -> some View {
        content
            .background(WindowAccessor { found in
                if window !== found { window = found }
            })
            .highPriorityGesture(
                DragGesture(minimumDistance: MovesWindowOnDrag.minimumDistance, coordinateSpace: .global)
                    .onChanged { _ in
                        guard let window else { return }
                        let mouse = NSEvent.mouseLocation
                        let start = dragStart ?? (mouse, window.frame.origin)
                        dragStart = start
                        window.setFrameOrigin(NSPoint(
                            x: start.origin.x + mouse.x - start.mouse.x,
                            y: start.origin.y + mouse.y - start.mouse.y
                        ))
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }
}

extension View {
    func movesWindowOnDrag() -> some View {
        modifier(MovesWindowOnDrag())
    }
}
