import SwiftUI

struct AnimatedStrikethroughText: View {
    let text: String
    let font: Font
    let color: Color
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(color.opacity(0.9))
                    .frame(height: 1.5)
                    .scaleEffect(x: isActive ? 1 : 0.001, y: 1, anchor: .leading)
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.16), value: isActive)
                    .allowsHitTesting(false)
            }
    }
}
