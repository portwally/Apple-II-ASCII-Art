import Foundation
import Combine

/// In-app diagnostic log. Anything written via `appLog(_:)` shows up both
/// in macOS Console (`print`) **and** in the live debug panel inside the
/// VideoConverter window — so we don't depend on the user opening
/// Console.app to see what the extractor is doing.
///
/// Threading: `append` hops to the main actor before mutating, so
/// `appLog(_:)` is safe to call from any queue / detached task.
@MainActor
final class AppDebugLog: ObservableObject {
    static let shared = AppDebugLog()

    @Published private(set) var lines: [String] = []

    /// Maximum number of lines retained (older lines drop off the top).
    private let cap = 200

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    func append(_ line: String) {
        let stamped = "\(formatter.string(from: Date())) \(line)"
        lines.append(stamped)
        if lines.count > cap { lines.removeFirst(lines.count - cap) }
    }

    func clear() { lines.removeAll() }
}

/// Master kill-switch for the in-app debug log.
///
/// While `false`, `appLog(_:)` is a no-op (no Console output, no entries in
/// `AppDebugLog.shared.lines`). The call sites throughout the pipeline are
/// left intact so we can flip this back to `true` whenever we need to see
/// what the extractor / converter is doing again. The debug-panel UI in
/// `VideoConverterView` is also commented out alongside this — re-enable
/// both together.
private let appLogEnabled = false

/// Thread-safe log function. Mirrors to Console **and** to the in-app
/// debug panel. Use this in place of `print(...)` anywhere in the
/// video pipeline.
func appLog(_ line: String) {
    guard appLogEnabled else { return }
    print(line)
    Task { @MainActor in
        AppDebugLog.shared.append(line)
    }
}
