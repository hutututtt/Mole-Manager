import SwiftUI

struct ContentView: View {
  @State private var appState: AppState = .idle
  @State private var appMode: AppMode = .cleaner  // New Mode State
  @State private var logs: [String] = []
  @State private var showAppList = false
  @State private var showCelebration = false
  @State private var celebrationColors: [Color] = []
  @State private var celebrationMessage: String = ""
  @Namespace private var animationNamespace

  // Connect to Real Logic
  @StateObject private var scanner = ScannerService()
  @StateObject private var uninstaller = UninstallerService()
  @StateObject private var optimizer = OptimizerService()
  @ObservedObject var authContext = AuthContext.shared

  // Mercury (Cleaner) - Dark Industrial Gray
  let mercuryColor = Color(red: 0.15, green: 0.15, blue: 0.18)

  // Mars (Uninstaller) - Deep Red
  let marsColor = Color(red: 0.25, green: 0.08, blue: 0.05)

  // Earth (Optimizer) - Deep Blue
  let earthColor = Color(red: 0.05, green: 0.1, blue: 0.25)

  var body: some View {
    ZStack {
      // Dynamic Background
      Color.black.ignoresSafeArea()

      RadialGradient(
        gradient: Gradient(colors: [
          appMode == .cleaner ? mercuryColor : (appMode == .uninstaller ? marsColor : earthColor),
          .black,
        ]),
        center: .center,
        startRadius: 0,
        endRadius: 600
      )
      .ignoresSafeArea()
      .animation(.easeInOut(duration: 0.5), value: appMode)

      // Custom Top Tab Bar
      VStack {
        TopBarView(
          appMode: $appMode, animationNamespace: animationNamespace, authContext: authContext
        )
        .padding(.top, 20)

        Spacer()
      }

      VStack(spacing: -10) {
        Spacer()

        // The Mole (Interactive) & Draggable
        // The Mole (Interactive) & Draggable
        MoleView(
          state: $appState,
          appMode: $appMode,
          isRunning: scanner.isScanning || scanner.isCleaning || optimizer.isOptimizing
            || uninstaller.isUninstalling
        )
        .gesture(
          DragGesture()
            .onEnded { value in
              if value.translation.width < -50 {
                withAnimation { appMode = .uninstaller }
              } else if value.translation.width > 50 {
                withAnimation { appMode = .cleaner }
              }
            }
        )
        .onHover { inside in
          if inside {
            NSCursor.pointingHand.set()
          } else {
            NSCursor.arrow.set()
          }
        }
        .opacity(showAppList ? 0.0 : 1.0)  // Hide when list is open
        .animation(.easeInOut, value: showAppList)
        .padding(.top, 75)  // Visual centering adjustment

        Spacer()  // Dynamic spacing

        // Status Area
        ZStack {
          // Logs overlay
          if case .scanning = appState, appMode == .cleaner {
            LogView(logs: logs)
              .transition(.opacity)
          } else if case .cleaning = appState, appMode == .cleaner {
            LogView(logs: logs)
              .transition(.opacity)
          } else if appMode == .optimizer && optimizer.isOptimizing {
            LogView(logs: logs)
              .transition(.opacity)
          } else if appMode == .uninstaller && uninstaller.isUninstalling {
            LogView(logs: logs)
              .transition(.opacity)
          } else if showAppList {
            // Showing App List? No status text needed or handled by overlay
            EmptyView()
          } else {
            // Action Button
            Button(action: {
              if appMode == .cleaner {
                startSmartClean()
              } else if appMode == .uninstaller {
                handleUninstallerAction()
              } else {
                handleOptimizerAction()
              }
            }) {
              HStack(spacing: 8) {
                if scanner.isScanning || scanner.isCleaning || optimizer.isOptimizing
                  || uninstaller.isUninstalling
                {
                  ProgressView()
                    .controlSize(.small)
                    .tint(.black)
                }

                Text("Mole")
                  .font(.system(size: 14, weight: .bold, design: .monospaced))
              }
              .frame(minWidth: 140)
              .padding(.vertical, 12)
              .background(Color.white)
              .foregroundStyle(.black)
              .clipShape(Capsule())
              .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .disabled(
              scanner.isScanning || scanner.isCleaning || optimizer.isOptimizing
                || uninstaller.isUninstalling
            )
            .onHover { inside in
              if inside { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
          }
        }
        .frame(height: 100)
        .padding(.bottom, 30)  // Anchor to bottom
      }

      // App List Overlay
      if showAppList {
        AppListView(
          apps: uninstaller.apps,
          onSelect: { app in
            handleUninstall(app)
          },
          onDismiss: {
            withAnimation { showAppList = false }
          }
        )
        .frame(width: 400, height: 550)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(10)
      }

      if showCelebration {
        VStack(spacing: 8) {
          ConfettiView(colors: celebrationColors)
            .offset(y: -50)

          VStack(spacing: 4) {
            Text("Success!")
              .font(.system(size: 24, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
              .shadow(radius: 5)
            if !celebrationMessage.isEmpty {
              Text(celebrationMessage)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 5)
            }
          }
          .offset(y: 105)
        }
        .allowsHitTesting(false)
        .zIndex(100)
        .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(minWidth: 600, minHeight: 500)
    .onChange(of: scanner.currentLog) {
      if !scanner.currentLog.isEmpty {
        withAnimation(.spring) {
          if appMode == .cleaner {
            logs.append(scanner.currentLog)
          }
        }
      }
    }
    .onChange(of: optimizer.currentLog) {
      if !optimizer.currentLog.isEmpty {
        withAnimation(.spring) {
          if appMode == .optimizer {
            logs.append(optimizer.currentLog)
          }
        }
      }
    }
    .onChange(of: uninstaller.currentLog) {
      if !uninstaller.currentLog.isEmpty {
        withAnimation(.spring) {
          if appMode == .uninstaller {
            logs.append(uninstaller.currentLog)
          }
        }
      }
    }
    .sheet(isPresented: $authContext.needsPassword) {
      PasswordSheetView(onUnlock: {
        // Unlock success implies AuthContext.password is set.
        // Services will use it on next attempt.
      })
    }
    .onChange(of: appMode) {
      appState = .idle
      logs.removeAll()
      showAppList = false
      showCelebration = false
      scanner.reset()
      optimizer.reset()
      uninstaller.reset()
    }
  }

  // MARK: - Actions

  func startSmartClean() {
    withAnimation {
      appState = .scanning
      logs.removeAll()
      showCelebration = false  // Dismiss old success
    }

    Task {
      await scanner.startScan()
      try? await Task.sleep(nanoseconds: 500_000_000)

      await MainActor.run {
        if scanner.totalSize > 0 {
          startCleaning()
        } else {
          withAnimation {
            appState = .idle
            logs.removeAll()
          }
          triggerCelebration([.white], message: "Already Clean")
        }
      }
    }
  }

  func startCleaning() {
    withAnimation {
      appState = .cleaning
      logs.removeAll()
      showCelebration = false
    }

    Task {
      let cleanedBytes = await scanner.cleanSystem()
      withAnimation {
        appState = .done
      }

      let mb = Double(cleanedBytes) / 1024.0 / 1024.0
      let msg =
        mb > 1024
        ? String(format: "Cleaned %.1f GB", mb / 1024.0) : String(format: "Cleaned %.0f MB", mb)

      triggerCelebration([.orange, .red, .yellow, .white], message: msg)
    }
  }

  func handleUninstallerAction() {
    withAnimation {
      showAppList = true
      showCelebration = false
    }
    Task { await uninstaller.scanApps() }
  }

  func handleUninstall(_ app: AppItem) {
    withAnimation {
      showAppList = false
      logs.removeAll()
      showCelebration = false
    }

    Task {
      await uninstaller.uninstall(app)
      triggerCelebration(
        [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint],
        message: "Uninstalled \(app.name)")
    }
  }

  func handleOptimizerAction() {
    showCelebration = false  // Immediate dismiss
    Task {
      await optimizer.optimize()
      triggerCelebration([.cyan, .blue, .purple, .mint, .white], message: "Optimized")
    }
  }

  func triggerCelebration(_ colors: [Color], message: String = "") {
    celebrationColors = colors
    celebrationMessage = message
    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCelebration = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
      withAnimation { showCelebration = false }
    }
  }
}

struct TopBarView: View {
  @Binding var appMode: AppMode
  var animationNamespace: Namespace.ID
  @ObservedObject var authContext: AuthContext

  var body: some View {
    ZStack {
      HStack(spacing: 0) {
        TabBarButton(mode: .cleaner, appMode: $appMode, namespace: animationNamespace)
        TabBarButton(mode: .uninstaller, appMode: $appMode, namespace: animationNamespace)
        TabBarButton(mode: .optimizer, appMode: $appMode, namespace: animationNamespace)
      }
      .padding(4)
      .background(Capsule().fill(.ultraThinMaterial).opacity(0.3))
    }
  }
}

struct TabBarButton: View {
  let mode: AppMode
  @Binding var appMode: AppMode
  var namespace: Namespace.ID

  var title: String {
    switch mode {
    case .cleaner: return "clean"
    case .uninstaller: return "uninstall"
    case .optimizer: return "optimize"
    }
  }

  var body: some View {
    Button(action: {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        appMode = mode
      }
    }) {
      Text(title)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(appMode == mode ? .black : .white.opacity(0.6))
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
          ZStack {
            if appMode == mode {
              Capsule()
                .fill(Color.white)
                .matchedGeometryEffect(id: "TabHighlight", in: namespace)
            }
          }
        )
    }
    .buttonStyle(.plain)
    .onHover { inside in
      if inside { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
    }
  }
}
