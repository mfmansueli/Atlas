//
//  ProductPageDeepLinkCheck.swift
//  Atlas
//

import Foundation

/// The line under a page's deep link field: optional when empty, an error
/// for a link that isn't complete ("lumen:/lock"), and whether it's one the
/// app opens. What the app opens is learned from the deep links its other
/// pages already use (their web domains and URL schemes).
struct ProductPageDeepLinkCheck: Hashable, Sendable {
    enum Result: Hashable, Sendable {
        /// No deep link: people land on the app's first screen.
        case empty
        /// A complete link the app opens, or one Atlas can't tell about.
        case fine(String)
        /// Not a complete link: it can't be pushed.
        case incomplete(String)
        /// A complete link to a place the app's other pages never use.
        case unfamiliar(String)
    }

    var link: String
    /// Web domains the app opens ("lumen.app").
    var domains: [String]
    /// The app's own URL schemes ("lumen").
    var schemes: [String] = []
    var appName: String = ""

    init(link: String, domains: [String], schemes: [String] = [], appName: String = "") {
        self.link = link.trimmingCharacters(in: .whitespaces)
        self.domains = domains
        self.schemes = schemes
        self.appName = appName
    }

    /// The domains and schemes of the deep links other pages use.
    init(link: String, knownLinks: [String], appName: String) {
        var domains: [String] = []
        var schemes: [String] = []
        for known in knownLinks {
            guard let url = URL(string: known), let scheme = url.scheme?.lowercased() else { continue }
            if scheme == "https" || scheme == "http" {
                if let host = url.host(), !domains.contains(host) { domains.append(host) }
            } else if !schemes.contains(scheme) {
                schemes.append(scheme)
            }
        }
        self.init(link: link, domains: domains, schemes: schemes, appName: appName)
    }

    var result: Result {
        guard !link.isEmpty else { return .empty }
        let name = appName.isEmpty ? String(localized: "The app") : appName
        guard let url = URL(string: link), let scheme = url.scheme?.lowercased(), Self.isComplete(link, url: url) else {
            return .incomplete(String(localized: "“\(link)” isn’t a complete link. \(name) opens links that start with \(examples)"))
        }
        if scheme == "https" || scheme == "http", let host = url.host() {
            guard !domains.isEmpty else { return .fine(String(localized: "A complete link. People who have \(name) tap Open and land here.")) }
            if domains.contains(host) {
                return .fine(String(localized: "\(name) opens this link: it matches \(host), the domain its other pages link to."))
            }
            return .unfamiliar(String(localized: "\(host) isn’t a domain \(name)’s other pages link to. Check it’s in the app’s associated domains."))
        }
        guard !schemes.isEmpty else { return .fine(String(localized: "A complete link. People who have \(name) tap Open and land here.")) }
        return schemes.contains(scheme)
            ? .fine(String(localized: "\(name) opens this link with its own \(scheme):// address."))
            : .unfamiliar(String(localized: "\(scheme):// isn’t an address \(name)’s other pages use."))
    }

    /// What stops the push: only a link that isn't complete.
    var blockingProblem: String? {
        if case let .incomplete(message) = result { return message }
        return nil
    }

    /// "https://lumen.app/ or lumen://".
    private var examples: String {
        let web = domains.map { "https://\($0)/" }
        let own = schemes.map { "\($0)://" }
        let all = web + own
        guard !all.isEmpty else { return String(localized: "https:// or the app’s own address, like myapp://") }
        return all.formatted(.list(type: .or))
    }

    /// A scheme, "://", and something after it.
    private static func isComplete(_ text: String, url: URL) -> Bool {
        guard let range = text.range(of: "://"), range.upperBound < text.endIndex else { return false }
        if let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" { return url.host()?.contains(".") == true }
        return true
    }
}
