import SwiftUI

struct AppListView: View {
  let apps: [AppItem]
  var onSelect: (AppItem) -> Void
  var onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Installed Apps")
          .font(.headline)
          .foregroundStyle(.white)
        Spacer()
        Button(action: onDismiss) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.gray)
            .font(.title2)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
      }
      .padding()
      .background(Color.black.opacity(0.8))

      // List
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(apps) { app in
            HStack {
              if let icon = app.icon {
                Image(nsImage: icon)
                  .resizable()
                  .frame(width: 32, height: 32)
              } else {
                Image(systemName: "app")
                  .resizable()
                  .foregroundStyle(.gray)
                  .frame(width: 32, height: 32)
              }

              VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                  .foregroundStyle(.white)
                  .font(.system(size: 14, weight: .medium))

                Text(app.size)
                  .foregroundStyle(.white.opacity(0.6))
                  .font(.system(size: 11, weight: .regular))
              }

              Spacer()

              Button(action: { onSelect(app) }) {
                Text("Uninstall")
                  .font(.system(size: 10, weight: .bold))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 6)
                  .background(Capsule().fill(Color(red: 1.0, green: 0.3, blue: 0.1).opacity(0.8)))
              }
              .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            .padding(.horizontal)
          }
        }
        .padding(.top)
        .padding(.bottom, 40)
      }
    }
    .background(Color.black.opacity(0.95))
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(radius: 20)
  }
}
