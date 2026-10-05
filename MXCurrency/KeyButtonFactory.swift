import SwiftUI

@ViewBuilder
func KeyButton(_ title: String, width: CGFloat, height: CGFloat, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 34, weight: .light, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: width, height: height)
            .background(Color.black)
    }
    .buttonStyle(.plain)
}
