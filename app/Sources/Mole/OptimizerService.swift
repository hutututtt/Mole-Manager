import Foundation

class OptimizerService: ObservableObject {
  @Published var isOptimizing = false
  @Published var statusMessage = ""
  @Published var currentLog = ""

  func reset() {
    self.currentLog = ""
    self.statusMessage = ""
    self.isOptimizing = false
  }

  func optimize() async {
    await MainActor.run {
      self.isOptimizing = true
      self.statusMessage = "Optimizing..."  // Removed "Authenticating..."
    }

    // Helper for Session Auth
    func runPrivileged(_ command: String) async throws {
      if let pw = AuthContext.shared.password {
        do {
          _ = try await ShellRunner.shared.runSudo(command, password: pw)
          return
        } catch {
          await MainActor.run { AuthContext.shared.clear() }
        }
      }

      // If no password or failed, prompt via Custom Sheet
      await MainActor.run {
        AuthContext.shared.needsPassword = true
        self.statusMessage = "Waiting for Password..."
      }

      // Abort execution until user authorizes
      struct AuthRequired: Error, LocalizedError {
        var errorDescription: String? { "Authorization Required" }
      }
      throw AuthRequired()
    }

    let steps: [(String, () async throws -> Void)] = [
      (
        "Flushing DNS Cache...",
        {
          // Use full paths for robustness
          let cmd = "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder"
          try await runPrivileged(cmd)
        }
      ),
      (
        "Purging Inactive Memory...",
        {
          try await runPrivileged("/usr/sbin/purge")
        }
      ),
      (
        "Rebuilding Launch Services...",
        {
          let lsregister =
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
          // Best effort
          _ = try? await ShellRunner.shared.run(
            lsregister,
            arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"])
        }
      ),
      (
        "Resetting QuickLook...",
        {
          _ = try? await ShellRunner.shared.run("/usr/bin/qlmanage", arguments: ["-r", "cache"])
          _ = try? await ShellRunner.shared.run("/usr/bin/qlmanage", arguments: ["-r"])
        }
      ),
      (
        "Restarting Finder...",
        {
          _ = try? await ShellRunner.shared.run("/usr/bin/killall", arguments: ["Finder"])
        }
      ),
    ]

    for (desc, action) in steps {
      await MainActor.run {
        self.statusMessage = desc
        self.currentLog = "Running: \(desc)"
      }

      do {
        try await action()
        try? await Task.sleep(nanoseconds: 500_000_000)
      } catch {
        await MainActor.run {
          // If user cancels osascript dialog, it throws error -128
          if error.localizedDescription.contains("User canceled") || "\(error)".contains("-128") {
            self.currentLog = "Optimization Cancelled by User"
          } else {
            self.currentLog = "Error: \(error.localizedDescription)"
          }
        }
      }
    }

    await MainActor.run {
      self.isOptimizing = false
      self.statusMessage = "System Optimized"
      self.currentLog = "Optimization Complete"
    }
  }
}
