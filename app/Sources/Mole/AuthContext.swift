import Combine
import Foundation

class AuthContext: ObservableObject {
  static let shared = AuthContext()
  @Published var needsPassword = false
  private(set) var password: String?

  init() {
    // Auto-login from Keychain
    if let saved = KeychainHelper.shared.load() {
      self.password = saved
    }
  }

  func setPassword(_ pass: String) {
    self.password = pass
    self.needsPassword = false
    // Persist
    KeychainHelper.shared.save(pass)
  }

  func clear() {
    self.password = nil
    // Remove persistence
    KeychainHelper.shared.delete()
  }
}
