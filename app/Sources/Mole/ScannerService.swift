import Combine
import Foundation

class ScannerService: ObservableObject {
  @Published var currentLog: String = ""
  @Published var totalSize: Int64 = 0
  @Published var isScanning = false
  @Published var isCleaning = false
  @Published var scanFinished = false

  // Reset State
  func reset() {
    self.currentLog = ""
    self.scanFinished = false
    self.isScanning = false
    self.isCleaning = false
    self.totalSize = 0
  }

  // User Paths (No Auth Needed)
  private var userPaths: [URL] = {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser
    let library = home.appendingPathComponent("Library")

    return [
      fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
      library.appendingPathComponent("Logs"),
      library.appendingPathComponent("Developer/Xcode/DerivedData"),
      library.appendingPathComponent("Developer/Xcode/Archives"),
      library.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"),
      library.appendingPathComponent("Developer/CoreSimulator/Caches"),
    ].compactMap { $0 }
  }()

  // System Paths (Auth Needed)
  private var systemPaths: [URL] = [
    URL(fileURLWithPath: "/Library/Caches"),
    URL(fileURLWithPath: "/Library/Logs"),
  ]

  // Scan Function
  func startScan() async {
    await MainActor.run {
      self.isScanning = true
      self.scanFinished = false
      self.totalSize = 0
    }

    var calculatedSize: Int64 = 0
    let fileManager = FileManager.default

    let allPaths = userPaths + systemPaths

    for url in allPaths {
      if !fileManager.fileExists(atPath: url.path) { continue }

      await MainActor.run {
        self.currentLog = "Scanning \(url.lastPathComponent)..."
      }

      // Enumeration (Skip permission errors silently)
      if let enumerator = fileManager.enumerator(
        at: url, includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants])
      {
        var counter = 0
        while let fileURL = enumerator.nextObject() as? URL {
          counter += 1
          if counter % 200 == 0 {
            let p = self.truncatePath(fileURL.path)
            await MainActor.run { self.currentLog = p }
            try? await Task.sleep(nanoseconds: 2_000_000)
          }

          do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resourceValues.fileSize {
              calculatedSize += Int64(fileSize)
            }
          } catch {
            continue
          }
        }
      }
    }

    let finalSize = calculatedSize
    await MainActor.run {
      self.totalSize = finalSize
      self.isScanning = false
      self.scanFinished = true
      self.currentLog = "Scan Complete"
    }
  }

  // Clean Function
  func cleanSystem() async -> Int64 {
    let startTime = Date()
    await MainActor.run {
      self.isCleaning = true
    }

    var cleanedSize: Int64 = 0
    let fileManager = FileManager.default

    // 1. Clean User Paths (Direct FileManager)
    for url in userPaths {
      if !fileManager.fileExists(atPath: url.path) { continue }
      await MainActor.run { self.currentLog = "Cleaning \(url.lastPathComponent)..." }

      do {
        let contents = try fileManager.contentsOfDirectory(
          at: url, includingPropertiesForKeys: [.fileSizeKey])
        for fileUrl in contents {
          if fileUrl.lastPathComponent == "." || fileUrl.lastPathComponent == ".." { continue }

          if let res = try? fileUrl.resourceValues(forKeys: [.fileSizeKey]), let s = res.fileSize {
            cleanedSize += Int64(s)
          }

          try? fileManager.removeItem(at: fileUrl)
        }
      } catch {}
    }

    // 2. Clean System Paths (Batch Admin Command)
    // We construct a command that deletes the *contents* of these directories
    var adminCommands: [String] = []
    for url in systemPaths {
      if fileManager.fileExists(atPath: url.path) {
        // Safe check: Only standard paths
        if url.path == "/Library/Caches" || url.path == "/Library/Logs" {
          adminCommands.append("rm -rf \"\(url.path)\"/*")
        }
      }
    }

    if !adminCommands.isEmpty {
      await MainActor.run { self.currentLog = "Authorizing System Cleanup..." }
      let fullCommand = adminCommands.joined(separator: "; ")

      if let sessionPw = AuthContext.shared.password {
        do {
          _ = try await ShellRunner.shared.runSudo(fullCommand, password: sessionPw)
        } catch {
          print("Session password failed: \(error)")
          await MainActor.run { AuthContext.shared.clear() }
          // Trigger re-auth on failure
          await MainActor.run {
            AuthContext.shared.needsPassword = true
            self.currentLog = "Password Incorrect/Expired"
            self.isCleaning = false
          }
          return 0
        }
      } else {
        // No password yet -> Prompt via Sheet
        await MainActor.run {
          AuthContext.shared.needsPassword = true
          self.currentLog = "Requires Authorization"
          self.isCleaning = false
        }
        return 0
      }
    }

    // Ensure minimum duration for UX
    let elapsed = Date().timeIntervalSince(startTime)
    if elapsed < 1.0 {
      try? await Task.sleep(nanoseconds: UInt64((1.0 - elapsed) * 1_000_000_000))
    }

    await MainActor.run {
      self.isCleaning = false
      self.scanFinished = false
      self.totalSize = 0
      self.currentLog = "Cleaned"
    }

    return cleanedSize
  }

  private func truncatePath(_ path: String) -> String {
    let home = NSHomeDirectory()
    let short = path.replacingOccurrences(of: home, with: "~")
    if short.count > 45 {
      let start = short.prefix(15)
      let end = short.suffix(25)
      return "\(start)...\(end)"
    }
    return short
  }
}
