#if canImport(OSLog)
import OSLog
#else
import Foundation

/// Non-Apple fallback for Apple's OSLog `Logger`, so AIProxy builds on
/// Linux/Windows. Errors/criticals go to stderr; lower levels are no-ops.
/// (No `privacy:` interpolation is used at AIProxy call sites, so plain-String
/// methods are sufficient.)
public struct Logger: Sendable {
    public init(subsystem: String, category: String) {}
    public func debug(_ message: String) {}
    public func info(_ message: String) {}
    public func notice(_ message: String) {}
    public func warning(_ message: String) {}
    public func error(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
    public func critical(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
    public func log(_ message: String) {}
}
#endif

nonisolated public enum AIProxyLogLevel: Int, Sendable {
    case debug
    case info
    case warning
    case error
    case critical

    func isAtOrAboveThresholdLevel(_ threshold: AIProxyLogLevel) -> Bool {
        return self.rawValue >= threshold.rawValue
    }

    /// This must only be accessed through `ProtectedPropertyQueue.callerDesiredLogLevel`.
    nonisolated(unsafe) static var _callerDesiredLogLevel = AIProxyLogLevel.warning
    /// Public so the optional `AIProxyRealtime` target (and other downstream
    /// extension targets) can read/update the threshold.
    nonisolated public static var callerDesiredLogLevel: AIProxyLogLevel {
        get {
            ProtectedPropertyQueue.callerDesiredLogLevel.sync { self._callerDesiredLogLevel }
        }
        set {
            ProtectedPropertyQueue.callerDesiredLogLevel.async(flags: .barrier) { self._callerDesiredLogLevel = newValue }
        }
    }
}

nonisolated internal let aiproxyLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "UnknownApp",
    category: "AIProxy"
)

// Why not create a wrapper around OSLog instead of forcing log callsites to include an `logIf(<level>)` check?
// Because I like the Xcode log feature that links to the source location of the log.
// If you create a wrapper, even one that is inlined, the Xcode source feature always links to the wrapper location.
//
// H/T Quinn the Eskimo!
// https://developer.apple.com/forums/thread/774931
/// Public so downstream extension targets (e.g. `AIProxyRealtime`) can use
/// the same gated-log helper that core uses internally.
@inline(__always)
nonisolated public func logIf(_ logLevel: AIProxyLogLevel) -> Logger? {
    return logLevel.isAtOrAboveThresholdLevel(AIProxyLogLevel.callerDesiredLogLevel) ? aiproxyLogger : nil
}
