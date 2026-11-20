//
//  InAppEventDeepLink.swift
//  Atlas
//

import Foundation

/// Where Open on an event's card and details page takes people in the
/// app, checked the way App Store Connect takes it: a URI, either a
/// universal link (`https://alba.app/events/new-year`) or the app's own
/// scheme (`alba://events/new-year`). App Store Connect refuses to send an
/// event to App Review without one ("You must provide a value for the
/// attribute 'deepLink'").
enum InAppEventDeepLink {
    /// Apple publishes no limit for the deep link; Atlas stops at 1,024
    /// characters, far beyond any link that works, so a pasted paragraph
    /// doesn't go.
    static let limit = 1024

    /// Why `text` can't be an event's deep link, saying what a working one
    /// looks like; nil when it can be. Empty is no problem here: whether
    /// the event needs one is `InAppEventReviewCheck`'s to say.
    static func problem(_ text: String, appName: String = "") -> String? {
        let link = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return nil }
        if link.count > limit { return String(localized: "The deep link is \(link.count) characters; the limit is \(limit).") }
        guard isValid(link) else {
            return String(localized: "The deep link isn’t a valid URL. \(example(appName: appName))")
        }
        if scheme(of: link) == "http" {
            return String(localized: "Links that start with http:// open in Safari, not in the app. Use https:// (a universal link) or the app’s own scheme.")
        }
        return nil
    }

    /// "Use a universal link (https://alba.app/event) or the app's own
    /// scheme (alba://event)."
    static func example(appName: String) -> String {
        let name = slug(appName)
        return String(localized: "Use a universal link (https://\(name).app/event) or the app’s own scheme (\(name)://event).")
    }

    /// A scheme, `://` for a web link (or after the app's own scheme), a
    /// host for web links, and no spaces.
    static func isValid(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text), let scheme = url.scheme,
              let first = scheme.unicodeScalars.first, CharacterSet.letters.contains(first),
              scheme.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "+-.".unicodeScalars.contains($0)) }),
              text.count > scheme.count + 1
        else { return false }
        if ["http", "https"].contains(scheme.lowercased()) { return url.host()?.isEmpty == false }
        return true
    }

    /// `alba` of `alba://events`, lowercased; nil when it has none.
    static func scheme(of text: String) -> String? {
        URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme?.lowercased()
    }

    /// `alba.app` of `https://alba.app/events`, lowercased; nil for the
    /// app's own scheme.
    static func webHost(of text: String) -> String? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http"
        else { return nil }
        return url.host()?.lowercased()
    }

    /// "Alba: Daily Motivation" → "alba", for examples.
    static func slug(_ appName: String) -> String {
        let word = appName.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).first.map(String.init) ?? ""
        let ascii = word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en_US_POSIX"))
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return ascii.isEmpty ? "myapp" : ascii.lowercased()
    }
}
