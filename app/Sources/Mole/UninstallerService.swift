import AppKit
import Foundation

struct AppItem: Identifiable, Equatable {
  let id = UUID()
  let name: String
  let url: URL
  let icon: NSImage?
  let size: String
}

class UninstallerService: ObservableObject {
  @Published var apps: [AppItem] = []
  @Published var isUninstalling = false
  @Published var currentLog = ""

  func reset() {
    self.currentLog = ""
    self.isUninstalling = false
  }

  init() {
    // Prefetch on launch
    Task {
      await scanApps()
    }
  }

  func scanApps() async {
    // If we already have data, don't block.
    if !apps.isEmpty { return }

    let fileManager = FileManager.default
    let appsDir = URL(fileURLWithPath: "/Applications")

    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: appsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

      // A. Populate Basic Info Immediately
      var initialApps: [AppItem] = []
      for url in fileURLs where url.pathExtension == "app" {
        let name = url.deletingPathExtension().lastPathComponent
        initialApps.append(AppItem(name: name, url: url, icon: nil, size: ""))
      }
      initialApps.sort { $0.name < $1.name }

      await MainActor.run { [initialApps] in
        self.apps = initialApps
      }

      // B. Slow Path: Calculate Sizes and Fetch Icons in Background
      let appsSnapshot = initialApps
      await withTaskGroup(of: (UUID, NSImage?, String).self) { group in
        for app in appsSnapshot {
          group.addTask { [app] in
            // Fetch Icon
            let icon = NSWorkspace.shared.icon(forFile: app.url.path)
            // Calculate Size
            let size = self.calculateSize(for: app.url)
            return (app.id, icon, size)
          }
        }

        for await (id, icon, sizeStr) in group {
          await MainActor.run {
            if let index = self.apps.firstIndex(where: { $0.id == id }) {
              let old = self.apps[index]
              self.apps[index] = AppItem(name: old.name, url: old.url, icon: icon, size: sizeStr)
            }
          }
        }
      }

    } catch {
      print("Error scanning apps: \(error)")
    }
  }

  func uninstall(_ app: AppItem) async {
    await MainActor.run {
      self.isUninstalling = true
      self.currentLog = "Analyzing \(app.name)..."
    }

    let fileManager = FileManager.default

    // 1. Get Bundle ID
    var bundleID: String?
    if let bundle = Bundle(url: app.url) {
      bundleID = bundle.bundleIdentifier
    }

    // Fallback if Bundle init fails
    if bundleID == nil {
      let plistUrl = app.url.appendingPathComponent("Contents/Info.plist")
      if let data = try? Data(contentsOf: plistUrl),
        let plist = try? PropertyListSerialization.propertyList(
          from: data, options: [], format: nil) as? [String: Any]
      {
        bundleID = plist["CFBundleIdentifier"] as? String
      }
    }

    var itemsToRemove: [URL] = []

    // 2. Find Related Files
    if let bid = bundleID {
      let home = FileManager.default.homeDirectoryForCurrentUser
      let library = home.appendingPathComponent("Library")

      // Potential Paths
      let candidates = [
        library.appendingPathComponent("Application Support/\(bid)"),
        library.appendingPathComponent("Caches/\(bid)"),
        library.appendingPathComponent("Preferences/\(bid).plist"),
        library.appendingPathComponent("Saved Application State/\(bid).savedState"),
        library.appendingPathComponent("Containers/\(bid)"),
        library.appendingPathComponent("WebKit/\(bid)"),
        library.appendingPathComponent("LaunchAgents/\(bid).plist"),
        library.appendingPathComponent("Logs/\(bid)"),
      ]

      for url in candidates {
        if fileManager.fileExists(atPath: url.path) {
          itemsToRemove.append(url)
        }
      }
    }

    // Add App itself
    itemsToRemove.append(app.url)

    // 3. Remove Items
    for item in itemsToRemove {
      await MainActor.run {
        let path = item.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        self.currentLog = "Removing \(path)..."
      }

      do {
        try fileManager.trashItem(at: item, resultingItemURL: nil)
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s for visual feedback
      } catch {
        print("Failed to trash \(item.path): \(error)")
      }
    }

    await MainActor.run {
      self.isUninstalling = false
      self.currentLog = "Uninstalled \(app.name)"
      if let idx = self.apps.firstIndex(of: app) {
        self.apps.remove(at: idx)
      }
    }
  }

  private func calculateSize(for url: URL) -> String {
    guard
      let enumerator = FileManager.default.enumerator(
        at: url, includingPropertiesForKeys: [.fileSizeKey])
    else { return "Unknown" }
    var totalSize: Int64 = 0
    for case let fileURL as URL in enumerator {
      do {
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resourceValues.fileSize {
          totalSize += Int64(fileSize)
        }
      } catch {}
    }
    return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
  }
}
