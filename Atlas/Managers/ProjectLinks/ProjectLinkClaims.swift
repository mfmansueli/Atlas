//
//  ProjectLinkClaims.swift
//  Atlas
//

import Foundation

/// The links an app's project says the app opens: the URL schemes in its
/// Info.plist (`CFBundleURLTypes` → `CFBundleURLSchemes`) and the domains
/// in its entitlements (`com.apple.developer.associated-domains`,
/// `applinks:`). That a link is claimed doesn't mean the app opens the
/// event on it: only reading the code (or trying it) tells.
struct ProjectLinkClaims: Hashable, Sendable {
    /// Lowercased: `alba`.
    var schemes: Set<String> = []
    /// Lowercased, as written after `applinks:`: `alba.app`, `*.alba.app`.
    var domains: Set<String> = []
    /// The app targets read: "Alba".
    var targets: [String] = []
    /// "1.2.0 (21)", from MARKETING_VERSION and CURRENT_PROJECT_VERSION.
    var build: String?

    /// Whether the app claims `link`'s scheme (`alba://…`) or, for a web
    /// link, its domain (`https://alba.app/…`).
    func claims(_ link: String) -> Bool {
        if let host = InAppEventDeepLink.webHost(of: link) { return claimsDomain(host) }
        guard let scheme = InAppEventDeepLink.scheme(of: link) else { return false }
        return schemes.contains(scheme)
    }

    /// `applinks:alba.app` claims alba.app; `applinks:*.alba.app` claims
    /// its subdomains (and, as Apple's matching does, alba.app itself).
    func claimsDomain(_ host: String) -> Bool {
        let host = host.lowercased()
        return domains.contains { domain in
            if domain.hasPrefix("*.") {
                let base = String(domain.dropFirst(2))
                return host == base || host.hasSuffix(".\(base)")
            }
            return domain == host
        }
    }
}
