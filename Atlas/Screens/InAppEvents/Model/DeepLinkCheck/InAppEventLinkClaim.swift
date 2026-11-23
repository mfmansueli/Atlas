//
//  InAppEventLinkClaim.swift
//  Atlas
//

import Foundation

/// Whether the app claims an event's deep link, as Atlas reads it in the
/// project folder, without an assistant: its URL scheme in the Info.plist,
/// or its domain in the entitlements' Associated Domains. A link the app
/// doesn't claim opens nothing (App Review taps Open and sees nothing
/// happen); one it claims may still not open the event, which only the
/// code tells.
enum InAppEventLinkClaim: Hashable, Sendable {
    case noDeepLink
    /// The project folder hasn't been read yet.
    case reading
    case noFolder
    case unreadable(reason: String)
    /// `alba://` or `alba.app`, which the project doesn't declare.
    case notClaimed(String)
    /// `alba://` or `alba.app`, which the project declares.
    case claimed(String)

    static func of(_ deepLink: String?, in state: ProjectLinkClaimsState) -> Self {
        guard let link = deepLink?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty,
              InAppEventDeepLink.problem(link) == nil
        else { return .noDeepLink }
        let what = Self.what(link)
        switch state {
        case .unknown: return .reading
        case .noFolder: return .noFolder
        case let .unreadable(_, reason): return .unreadable(reason: reason)
        case let .read(_, claims): return claims.claims(link) ? .claimed(what) : .notClaimed(what)
        }
    }

    /// `alba://` for the app's own scheme, `alba.app` for a web link.
    static func what(_ link: String) -> String {
        if let host = InAppEventDeepLink.webHost(of: link) { return host }
        return "\(InAppEventDeepLink.scheme(of: link) ?? link)://"
    }

    /// Submit stays off: App Review would tap Open and nothing would open.
    var blocksSubmit: Bool {
        if case .notClaimed = self { return true }
        return false
    }

    /// The person can do something about it here: choose the folder.
    var needsFolder: Bool {
        switch self {
        case .noFolder, .unreadable: true
        case .noDeepLink, .reading, .notClaimed, .claimed: false
        }
    }

    /// "Alba doesn't open alba:// links yet", "alba:// is Alba's, but
    /// Atlas can't tell whether it opens this event."
    func message(appName: String) -> String? {
        switch self {
        case .noDeepLink, .reading:
            nil
        case .noFolder:
            String(localized: "Choose \(appName)’s project folder so Atlas can check whether \(appName) opens this link.")
        case let .unreadable(reason):
            String(localized: "Atlas can’t tell whether \(appName) opens this link. \(reason)")
        case let .notClaimed(what):
            if what.hasSuffix("://") {
                String(localized: "\(appName) doesn’t open \(what) links yet")
            } else {
                String(localized: "\(appName) doesn’t open links to \(what) yet")
            }
        case let .claimed(what):
            String(localized: "\(what) is \(appName)’s, but Atlas can’t tell whether it opens this event.")
        }
    }

    /// Where the project would claim it: "Its Info.plist declares no URL
    /// scheme alba."
    var detail: String? {
        guard case let .notClaimed(what) = self else { return nil }
        if what.hasSuffix("://") {
            return String(localized: "Its Info.plist declares no URL scheme “\(String(what.dropLast(3)))” (URL Types), so the link opens nothing.")
        }
        return String(localized: "Its entitlements have no applinks:\(what) (Associated Domains), so the link opens in Safari, not in the app.")
    }

    /// `get_in_app_events`' `deepLinkClaim.state`.
    var mcpValue: String {
        switch self {
        case .noDeepLink: "noDeepLink"
        case .reading: "notReadYet"
        case .noFolder: "noProjectFolder"
        case .unreadable: "unreadable"
        case .notClaimed: "notClaimed"
        case .claimed: "claimed"
        }
    }
}
