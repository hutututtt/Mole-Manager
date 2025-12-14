import AppKit
import SwiftUI

// MARK: - NSVisualEffectView bridge (Liquid Glass / blur)
struct VisualEffectBlur: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .hudWindow
  var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
  var state: NSVisualEffectView.State = .active

  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.material = material
    v.blendingMode = blendingMode
    v.state = state
    v.wantsLayer = true
    return v
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.state = state
  }
}

struct PasswordSheetView: View {
  @State private var passwordInput = ""
  @Environment(\.presentationMode) var presentationMode
  var onUnlock: () -> Void
  @FocusState private var isFocused: Bool

  private var accent: Color { Color.accentColor }

  var body: some View {
    dialogCard
      .frame(width: 280)
      // Attempt to clear window background for true glass effect
      .background(ClearBackgroundView())
  }

  private var dialogCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Icon
      ZStack(alignment: .bottomTrailing) {
        if let url = Bundle.module.url(forResource: "mole", withExtension: "png"),
          let customIcon = NSImage(contentsOf: url)
        {
          Image(nsImage: customIcon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
            .shadow(radius: 2)
        } else {
          Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
            .shadow(radius: 2)
        }
      }
      .padding(.leading, 6)

      // Title + message
      VStack(alignment: .leading, spacing: 5) {
        Text("Mole is trying to make changes.")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.primary)

        Text("Enter your password to allow this.")
          .font(.system(size: 12, weight: .regular))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      // Fields
      VStack(spacing: 12) {
        // Username field
        HStack {
          Text(NSUserName())
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary.opacity(0.85))
          Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(fieldBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(.white.opacity(0.10), lineWidth: 1)
        )

        // Password field
        ZStack(alignment: .leading) {
          SecureField("", text: $passwordInput)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .focused($isFocused)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .onSubmit(submit)

          if passwordInput.isEmpty {
            Text("Password")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.primary.opacity(0.35))
              .padding(.leading, 10)
              .allowsHitTesting(false)
          }
        }
        .background(fieldBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(.white.opacity(0.10), lineWidth: 1)
        )
      }
      .padding(.top, 2)

      // Buttons
      HStack(spacing: 12) {
        Button("Cancel") {
          presentationMode.wrappedValue.dismiss()
        }
        .buttonStyle(.plain)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(buttonGlassBackground)
        .clipShape(Capsule())
        .keyboardShortcut(.cancelAction)

        Button("Allow") {
          submit()
        }
        .buttonStyle(.plain)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Color(nsColor: .controlAccentColor))
        .clipShape(Capsule())
        .keyboardShortcut(.defaultAction)
        .disabled(passwordInput.isEmpty)
      }
      .padding(.top, 4)
    }
    .padding(20)
    .background(glassBackground)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(.white.opacity(0.18), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.22), radius: 30, x: 0, y: 18)
    .onAppear {
      isFocused = true
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  private var glassBackground: some View {
    ZStack {
      VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow, state: .active)
      LinearGradient(
        colors: [.white.opacity(0.55), .white.opacity(0.22), .black.opacity(0.08)],
        startPoint: .top, endPoint: .bottom
      )
    }
  }

  private var fieldBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .fill(.black.opacity(0.10))
      .background(
        VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow, state: .active)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .opacity(0.45)
      )
  }

  private var buttonGlassBackground: some View {
    ZStack {
      VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow, state: .active)
      LinearGradient(
        colors: [.white.opacity(0.25), .black.opacity(0.06)],
        startPoint: .top, endPoint: .bottom
      )
    }
  }

  func submit() {
    guard !passwordInput.isEmpty else { return }
    AuthContext.shared.setPassword(passwordInput)
    onUnlock()
    presentationMode.wrappedValue.dismiss()
  }
}

/// Helper to reset window background for clean glass effect in sheets
struct ClearBackgroundView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      view.window?.backgroundColor = .clear
      view.window?.isOpaque = false
    }
    return view
  }
  func updateNSView(_ nsView: NSView, context: Context) {}
}
