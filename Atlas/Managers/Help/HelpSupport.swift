//
//  HelpSupport.swift
//  Atlas
//

import AppKit

/// Help → Contact Support… and Send Feedback…: an email with Atlas's
/// version and nothing else, to the address in the Info.plist's
/// `ALSupportEmail` (left for the person to fill in until it's set); and
/// Apple's system status page.
@MainActor
enum HelpSupport {
    static let systemStatusURL = URL(string: "https://developer.apple.com/system-status/")

    static var supportEmail: String? {
        Bundle.main.object(forInfoDictionaryKey: "ALSupportEmail") as? String
    }

    /// "Atlas 1.0 (42)".
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Atlas \(version) (\(build))"
    }

    static func contactSupport() {
        compose(subject: String(localized: "Support: \(versionLine)"))
    }

    static func sendFeedback() {
        compose(subject: String(localized: "Feedback: \(versionLine)"))
    }

    static func openSystemStatus() {
        if let systemStatusURL { NSWorkspace.shared.open(systemStatusURL) }
    }

    /// The mail app's compose window, or a mailto: link without one.
    private static func compose(subject: String) {
        let recipients = supportEmail.map { [$0] } ?? []
        if let service = NSSharingService(named: .composeEmail), service.canPerform(withItems: [""]) {
            service.recipients = recipients
            service.subject = subject
            service.perform(withItems: [""])
            return
        }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = recipients.first ?? ""
        parts.queryItems = [URLQueryItem(name: "subject", value: subject)]
        if let url = parts.url { NSWorkspace.shared.open(url) }
    }
}
