import Foundation

// Note: Switched to File-based storage to avoid repetitive System Keychain prompts
// during development (Unsigned Binary). Files are set to 600 layout (User Only).
class KeychainHelper {
  static let shared = KeychainHelper()

  private var storeURL: URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".mole").appendingPathComponent(".key")
  }

  func save(_ data: String) {
    let url = storeURL
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url, atomically: true, encoding: .utf8)
      // Set permissions to User Read/Write Only (600) for security
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    } catch {
      print("Failed to save credentials: \(error)")
    }
  }

  func load() -> String? {
    do {
      return try String(contentsOf: storeURL, encoding: .utf8)
    } catch {
      return nil
    }
  }

  func delete() {
    try? FileManager.default.removeItem(at: storeURL)
  }
}
