import SwiftUI

struct LogView: View {
  let logs: [String]

  var body: some View {
    VStack(alignment: .center, spacing: 6) {
      ForEach(Array(logs.suffix(3).enumerated()), id: \.offset) { index, log in
        Text(log)
          .font(.system(size: 12, weight: .regular, design: .monospaced))
          .foregroundStyle(.white.opacity(opacity(for: index, count: logs.suffix(3).count)))
          .frame(maxWidth: .infinity, alignment: .center)
          .transition(.opacity)
      }
    }
    .frame(height: 60)
    .mask(
      LinearGradient(
        gradient: Gradient(stops: [
          .init(color: .clear, location: 0),
          .init(color: .black, location: 0.3),
          .init(color: .black, location: 1.0),
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .offset(y: -25)
  }

  func opacity(for index: Int, count: Int) -> Double {
    // Newer items (higher index) are more opaque
    let normalizedIndex = Double(index) / Double(max(count - 1, 1))
    return 0.3 + (normalizedIndex * 0.7)
  }
}
