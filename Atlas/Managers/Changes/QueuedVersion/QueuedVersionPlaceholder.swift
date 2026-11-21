//
//  QueuedVersionPlaceholder.swift
//  Atlas
//

import Foundation

/// Something of a new version that App Store Connect creates in the same
/// push, named in a request before it has an ID:
/// `{queuedVersion:IOS:1.2}` (the version),
/// `{queuedVersion:IOS:1.2:localization:en-US}` (its localization of a
/// language, copied from the version before) and
/// `{queuedVersion:IOS:1.2:reviewDetail}` (its App Review details), and
/// the app info App Store Connect makes with it, for name, subtitle,
/// privacy URLs and categories (`{queuedVersion:IOS:1.2:appInfo}`,
/// `{queuedVersion:IOS:1.2:appInfoLocalization:en-US}`,
/// `{queuedVersion:IOS:1.2:ageRating}` for its age rating declaration):
/// the live one can't change name or subtitle. The push fills them in once the version is created
/// (`QueuedVersionPushState`).
struct QueuedVersionPlaceholder: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case version
        case localization(String)
        case reviewDetail
        case appInfo
        case appInfoLocalization(String)
        case ageRating
    }

    var kind: Kind
    var platform: String
    var versionString: String

    static let opening = "{queuedVersion:"

    var token: String {
        let version = "\(Self.opening)\(platform):\(versionString)"
        switch kind {
        case .version: return "\(version)}"
        case let .localization(locale): return "\(version):localization:\(locale)}"
        case .reviewDetail: return "\(version):reviewDetail}"
        case .appInfo: return "\(version):appInfo}"
        case let .appInfoLocalization(locale): return "\(version):appInfoLocalization:\(locale)}"
        case .ageRating: return "\(version):ageRating}"
        }
    }

    init(kind: Kind, platform: String, versionString: String) {
        self.kind = kind
        self.platform = platform
        self.versionString = versionString
    }

    /// The placeholder `token` spells; nil for anything else.
    init?(token: String) {
        guard token.hasPrefix(Self.opening), token.hasSuffix("}") else { return nil }
        let parts = token.dropFirst(Self.opening.count).dropLast().split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, !parts[1].isEmpty, let kind = Self.kind(Array(parts.dropFirst(2))) else { return nil }
        platform = parts[0]
        versionString = parts[1]
        self.kind = kind
    }

    /// The kind a token's parts after the version spell.
    private static func kind(_ parts: [String]) -> Kind? {
        guard let name = parts.first else { return .version }
        let locale = parts.count == 2 && !parts[1].isEmpty ? parts[1] : nil
        switch (name, parts.count) {
        case ("localization", _): return locale.map(Kind.localization)
        case ("appInfoLocalization", _): return locale.map(Kind.appInfoLocalization)
        case ("reviewDetail", 1): return .reviewDetail
        case ("appInfo", 1): return .appInfo
        case ("ageRating", 1): return .ageRating
        default: return nil
        }
    }

    /// Every placeholder in `request`'s path and body, in order.
    static func all(in request: PushRequest) -> [QueuedVersionPlaceholder] {
        all(in: request.path + "\n" + (request.bodyText ?? ""))
    }

    static func all(in text: String) -> [QueuedVersionPlaceholder] {
        var found: [QueuedVersionPlaceholder] = []
        var rest = text[...]
        while let start = rest.range(of: opening), let end = rest[start.lowerBound...].firstIndex(of: "}") {
            if let placeholder = QueuedVersionPlaceholder(token: String(rest[start.lowerBound...end])) { found.append(placeholder) }
            rest = rest[rest.index(after: end)...]
        }
        return found
    }

    /// The version wasn't created, in this push or an earlier one: its
    /// texts stay queued and go out once it is.
    struct NotCreated: LocalizedError, Equatable {
        var versionString: String

        var errorDescription: String? {
            String(localized: "Version \(versionString) isn’t in App Store Connect yet, so its texts wait. Push the version first.")
        }
    }

    /// App Store Connect has no app information for the new version, or
    /// no age rating declaration on it.
    struct NoAppInfo: LocalizedError, Equatable {
        var versionString: String

        var errorDescription: String? {
            String(localized: "App Store Connect has no app information for version \(versionString) yet. Try again in a minute.")
        }
    }

    /// App Store Connect's new version has no localization of a language
    /// its texts were written in.
    struct MissingLocalization: LocalizedError, Equatable {
        var locale: String
        var versionString: String

        var errorDescription: String? {
            let name = StoreLocaleCatalog.locale(code: locale)?.name ?? locale
            return String(localized: "Version \(versionString) has no \(name) page in App Store Connect.")
        }
    }
}
