import SwiftUI

struct ConfettiView: View {
  var colors: [Color] = [.red, .blue, .green, .yellow]

  var body: some View {
    ZStack {
      ForEach(0..<100, id: \.self) { i in
        ConfettiPiece(
          color: colors.randomElement() ?? .white,
          angle: .degrees(Double(i) * 360 / 100)
        )
      }
    }
  }
}

struct ConfettiPiece: View {
  let color: Color
  let angle: Angle

  @State private var offset: CGFloat = 0
  @State private var opacity: Double = 1
  @State private var scale: CGFloat = 0.1
  // Randomize properties per piece
  let size: CGFloat = CGFloat.random(in: 3...9)

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: size, height: size)
      .scaleEffect(scale)
      .offset(x: offset)
      .rotationEffect(angle)
      .opacity(opacity)
      .onAppear {
        let duration = Double.random(in: 1.0...2.5)
        withAnimation(.easeOut(duration: duration)) {
          offset = CGFloat.random(in: 100...350)
          scale = 1.0
          opacity = 0
        }
      }
  }
}
