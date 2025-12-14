import Foundation

enum ShellError: Error, LocalizedError {
  case commandFailed(output: String)
  case executionError(error: Error)

  var errorDescription: String? {
    switch self {
    case .commandFailed(let output): return output
    case .executionError(let error): return error.localizedDescription
    }
  }
}

class ShellRunner {
  static let shared = ShellRunner()

  private init() {}

  /// Runs a shell command as the current user
  func run(_ command: String, arguments: [String] = []) async throws -> String {
    let process = Process()
    let pipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [command] + arguments
    process.standardOutput = pipe
    process.standardError = errorPipe

    return try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { process in
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Also capture error output
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
          continuation.resume(returning: output)
        } else {
          // Combine stdout and stderr for debugging
          continuation.resume(
            throwing: ShellError.commandFailed(output: output + "\n" + errorOutput))
        }
      }

      do {
        try process.run()
      } catch {
        continuation.resume(throwing: ShellError.executionError(error: error))
      }
    }
  }

  /// Runs a full shell command string (e.g. involving pipes or multiple args)
  func runShell(_ command: String) async throws -> String {
    return try await run("bash", arguments: ["-c", command])
  }

  /// Runs a command with Administrator privileges using AppleScript
  /// Note: This will trigger the system permission dialog
  func runAdmin(_ command: String) async throws -> String {
    // Escape quotes and backslashes for AppleScript string to prevent syntax errors
    let escapedCommand =
      command
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")

    let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
    return try await run("osascript", arguments: ["-e", appleScript])
  }

  /// Runs a command with sudo using a provided password (via stdin)
  func runSudo(_ command: String, password: String) async throws -> String {
    let process = Process()
    let pipe = Pipe()
    let errorPipe = Pipe()
    let inputPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    // -S reads password from stdin, -p '' disables the prompt string
    // We wrap the actual command in bash -c to handle complex strings
    process.arguments = ["-S", "-p", "", "bash", "-c", command]
    process.standardOutput = pipe
    process.standardError = errorPipe
    process.standardInput = inputPipe

    return try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { process in
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
          continuation.resume(returning: output)
        } else {
          // If 1, it might be wrong password or command fail.
          // sudo usually complains to stderr.
          continuation.resume(
            throwing: ShellError.commandFailed(output: errorOutput.isEmpty ? output : errorOutput))
        }
      }

      do {
        try process.run()
        // Write password to stdin
        if let passData = (password + "\n").data(using: .utf8) {
          try? inputPipe.fileHandleForWriting.write(contentsOf: passData)
          try? inputPipe.fileHandleForWriting.close()
        }
      } catch {
        continuation.resume(throwing: ShellError.executionError(error: error))
      }
    }
  }
}
