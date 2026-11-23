//
//  EncryptionKeyCardModel.swift
//  Atlas
//

import Foundation

/// What "Skip the question for every build" shows: done (and how Atlas
/// knows), the key to copy, Add It to the Project with why it's off, an
/// assistant's problem with Try Again, or a key that says something else
/// than the answers.
struct EncryptionKeyCardModel: Hashable, Sendable {
    var readiness: EncryptionKeyReadiness
    var detection: EncryptionKeyDetection
    /// The app's last report, whatever its status.
    var report: EncryptionKeyReport?
    /// What the page's answers add up to, settled or not.
    var shownValue: EncryptionKeyValue?
    /// An Add It to the Project run is going.
    var isRunning = false

    /// What the key should say: the settled answer's, else the page's.
    var expectedValue: EncryptionKeyValue? {
        readiness.answer?.value ?? shownValue
    }

    /// The key Atlas knows of says something else than the answers (or
    /// names another declaration's code).
    var conflict: Bool {
        guard let found = detection.value, let expected = expectedValue else { return false }
        if found != expected { return true }
        guard found == .yes, let code = readiness.answer?.code, let foundCode = detectedCode else { return false }
        return code != foundCode
    }

    private var detectedCode: String? {
        switch detection {
        case let .reported(report): report.code
        case let .inProject(key): key.code
        default: nil
        }
    }

    /// The builds answer it already, the way the answers say.
    var isDone: Bool { detection.isDone && !conflict }

    /// The assistant's last report says it couldn't add it.
    var problem: String? {
        guard !isDone, let report, report.status == .couldNotAdd else { return nil }
        let reason = report.reason ?? report.notes ?? ""
        return reason.isEmpty ? report.headline : "\(report.headline): \(reason)"
    }

    /// "The project says NO, but the answers say the encryption isn't
    /// exempt: change the key before the next upload."
    var conflictText: String? {
        guard conflict, let found = detection.value, let expected = expectedValue else { return nil }
        if found == expected {
            return String(localized: "The key names another encryption declaration’s code than the approved one. Change it before the next upload.")
        }
        return String(localized: """
        The key says \(found.rawValue), but the answers say \(expected.meaning) (\(expected.rawValue)). Change it before the next upload: \
        every build answers with it.
        """)
    }

    /// The ask button's title.
    var buttonTitle: String {
        if conflict { return String(localized: "Change It in the Project…") }
        if problem != nil { return String(localized: "Try Again") }
        if case .inferred = detection { return String(localized: "Check in the Project…") }
        return String(localized: "Add It to the Project…")
    }

    /// Done from a report or the project needs no button; inferred keeps
    /// Check in the Project….
    var showsButton: Bool {
        guard isDone else { return true }
        if case .inferred = detection { return true }
        return false
    }

    /// Why the button is off.
    var disabledReason: String? {
        showsButton ? readiness.reason?.text : nil
    }

    /// The Info.plist lines to copy.
    var snippet: String {
        readiness.answer?.snippet ?? EncryptionKeyAnswer.snippet(value: shownValue ?? .no, code: nil)
    }

    /// The build setting, for a target that generates its Info.plist.
    var buildSetting: String {
        readiness.answer?.buildSettings.joined(separator: "\n")
            ?? "INFOPLIST_KEY_\(EncryptionKeyAnswer.key) = \((shownValue ?? .no).rawValue)"
    }
}
