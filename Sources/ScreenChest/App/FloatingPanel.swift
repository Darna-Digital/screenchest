import SwiftUI

struct FloatingPanel: ViewModifier {
    static let cornerRadius: CGFloat = 26
    static let windowPadding: CGFloat = 28

    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.black.opacity(0.55))
            .background(.regularMaterial)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
    }
}

extension View {
    func floatingPanel(cornerRadius: CGFloat = FloatingPanel.cornerRadius) -> some View {
        modifier(FloatingPanel(cornerRadius: cornerRadius))
    }
}

struct ProminentPanelButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .red
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .fontWeight(.semibold)
                    .fixedSize()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SubtlePanelButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .fixedSize()
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
