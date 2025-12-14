import SceneKit
import SwiftUI

struct MoleView: View {
  @Binding var state: AppState
  @Binding var appMode: AppMode  // New binding
  var isRunning: Bool  // Fast Spin Trigger

  @State private var dragVelocity = CGSize.zero

  // We hold a SceneKit scene instance to manipulate it directly if needed, or let the Representable handle it.
  // To enable "Drag to Spin", we pass gesture data to the representable.

  var body: some View {
    GeometryReader { proxy in
      let minDim = min(proxy.size.width, proxy.size.height)
      // Tiers: Small (Default) -> Medium -> Large
      let planetSize: CGFloat = {
        if minDim < 600 { return 320 } else if minDim < 900 { return 450 } else { return 580 }
      }()

      ZStack {
        // Background Atmosphere (2D Glow)
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [
                Color(hue: 0.6, saturation: 0.8, brightness: 0.6).opacity(0.3),
                Color.purple.opacity(0.1),
                .clear,
              ]),
              center: .center,
              startRadius: planetSize * 0.25,
              endRadius: planetSize * 0.56
            )
          )
          .frame(width: planetSize * 0.94, height: planetSize * 0.94)
          .blur(radius: 20)

        // The 3D Scene
        MoleSceneView(
          state: $state, rotationVelocity: $dragVelocity, activeColor: appMode.themeColor,
          appMode: appMode,
          isRunning: isRunning
        )
        .frame(width: planetSize, height: planetSize)
        .mask(Circle())
        .contentShape(Circle())  // Ensure interaction only happens on the circle
        .onHover { inside in
          if inside {
            NSCursor.openHand.set()
          } else {
            NSCursor.arrow.set()
          }
        }
        .gesture(
          DragGesture()
            .onChanged { gesture in
              // Pass simplified velocity/delta for the Scene to rotate
              dragVelocity = CGSize(
                width: gesture.translation.width, height: gesture.translation.height)
              NSCursor.closedHand.set()  // Grabbing effect
            }
            .onEnded { _ in
              dragVelocity = .zero  // Resume auto-spin (handled in view)
              NSCursor.openHand.set()  // Release grab
            }
        )
      }
      .scaleEffect(state == .cleaning ? 0.95 : 1.0)
      .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
    }
    .animation(.spring, value: state)
  }
}
