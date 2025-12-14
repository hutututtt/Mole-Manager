import Foundation
import SwiftUI

enum AppMode: Equatable {
  case cleaner
  case uninstaller
  case optimizer  // New Mode

  // Reverting to tuple format for compatibility with SceneView if needed, or stick to Color?
  // Let's stick to Color for now but ContentView might need adjustment if it expected tuple?
  // Wait, previous file had (Double, Double, Double).
  // If I change it to Color, I break SceneView if it uses the tuple.
  // Checking SceneView usage...
  // SceneView uses `appMode.themeColor` to set `material.diffuse.contents` fallback or logic.
  // SceneView expects `(Double, Double, Double)` in `activeColor` binding?
  // I should check SceneView signature.
  // For safety, I will keep themeColor as Tuple OR add a new property.
  // Let's start by fixing the compilation error (Markdown fences).

  var themeColor: (Double, Double, Double) {
    switch self {
    case .cleaner: return (0.45, 0.12, 0.05)  // Deep Mars
    case .uninstaller: return (0.35, 0.35, 0.4)  // Deep Moon
    case .optimizer: return (0.0, 0.2, 0.8)  // Neptune Blue (RGB values approx)
    }
  }

  var title: String {
    switch self {
    case .cleaner: return "Cleaner"
    case .uninstaller: return "Uninstaller"
    case .optimizer: return "Optimizer"
    }
  }
}
