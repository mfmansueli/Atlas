//
//  PretendMacRunner.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Synchronization
@testable import Atlas

/// The helper on a pretend Mac (`DebugSimulators.Mac`) that changes as it's
/// asked: `create-simulator` makes the Duo once its runtime is there (or
/// fails with `createFailure` on stderr), `install-platform` installs the
/// runtime, and the Duo boots closed. Its own Mac, unlike
/// `DebugSimulators.mac`, so tests can run side by side. Every call's
/// arguments are recorded.
final class PretendMacRunner: UnixScriptRunning, @unchecked Sendable {
    let mac: Mutex<DebugSimulators.Mac>
    /// What `create-simulator` writes to stderr when it fails; nil: it
    /// works.
    var createFailure: String?
    private let calls = Mutex<[[String]]>([])

    init(_ mac: DebugSimulators.Mac) {
        self.mac = Mutex(mac)
    }

    var recordedArguments: [[String]] {
        calls.withLock { $0 }
    }

    /// The calls of one of the helper's modes.
    func calls(_ mode: String) -> [[String]] {
        recordedArguments.filter { $0.first == mode }
    }

    func exists(_: URL) -> Bool {
        true
    }

    func run(_: URL, arguments: [String], onLine: @escaping @Sendable (String) -> Void) async -> UnixScriptExit {
        calls.withLock { $0.append(arguments) }
        let (status, errorOutput) = answer(arguments, onLine: onLine)
        onLine("\(ClaudeCodeHelperScript.exitMarker) \(status)")
        return UnixScriptExit(errorOutput: errorOutput, taskError: status == 0 ? nil : "The script exited with status \(status).")
    }

    /// The lines of one call; its status and what it wrote to stderr.
    private func answer(_ arguments: [String], onLine: (String) -> Void) -> (Int32, String) {
        switch arguments.first {
        case "check":
            FakeUnixScriptRunner.foundLines.forEach(onLine)
        case "simulators":
            onLine(DebugSimulators.json(mac.withLock { $0 }))
        case "install-platform":
            DebugSimulators.downloadLines.forEach(onLine)
            mac.withLock { $0.hasNewRuntime = true }
        case "create-simulator":
            if let createFailure { return (1, createFailure) }
            mac.withLock { $0.hasDuo = $0.hasNewRuntime }
            onLine("6F0D2C5E-0A3B-4C1D-9E8F-1A2B3C4D5E6F")
        default:
            return answerDuo(arguments, onLine: onLine)
        }
        return (0, "")
    }

    /// The Duo's modes: it boots closed.
    private func answerDuo(_ arguments: [String], onLine: (String) -> Void) -> (Int32, String) {
        switch arguments.first {
        case "simulator-displays":
            guard mac.withLock({ $0.duoIsBooted }) else { return (149, "Unable to lookup in current state: Shutdown") }
            DebugSimulators.displayLines.forEach(onLine)
        case "simulator-screenshot":
            onLine(DebugSimulators.png(mac.withLock { $0.duoInner }).base64EncodedString())
        case "boot-simulator":
            mac.withLock { mac in
                mac.duoIsBooted = true
                mac.duoInner = .black
            }
        case "shutdown-simulator":
            mac.withLock { $0.duoIsBooted = false }
        case "accessibility":
            onLine("trusted")
        default:
            break
        }
        return (0, "")
    }
}
#endif
