//
//  ReviewRiskProjectFacts.swift
//  Atlas
//

import Foundation

/// What the app's Xcode project folder shows, read without building it
/// (`ReviewRiskProjectReader`). `packages` and `imports` are shared with
/// other checks (China mainland's AI content reads them); the rest feeds
/// the account deletion, Sign in with Apple and permission text checks.
struct ReviewRiskProjectFacts: Hashable, Sendable {
    /// At most this many matches are kept per signal or permission.
    static let matchLimit = 20

    /// The folder's name, for evidence: "Bruma".
    var folderName: String
    /// Dependency names, lowercased, from Package.resolved, Podfile.lock
    /// and Cartfile.resolved, e.g. "googlesignin-ios", "openai".
    var packages: Set<String> = []
    /// Modules imported in the Swift sources, e.g. "AuthenticationServices",
    /// "FoundationModels".
    var imports: Set<String> = []
    /// Entitlement keys set in any *.entitlements, e.g.
    /// "com.apple.developer.applesignin".
    var entitlements: Set<String> = []
    /// Permission texts by key ("NSCameraUsageDescription"), from the
    /// Info.plist files and `INFOPLIST_KEY_…` build settings.
    var purposeStrings: [String: ReviewRiskPurposeString] = [:]
    /// Where the code uses an API that needs a permission text.
    var permissionUses: [ReviewRiskPermission: [ReviewRiskCodeMatch]] = [:]
    /// Where the code creates, signs in to or deletes accounts, and signs in
    /// with Apple or another company.
    var signals: [ReviewRiskCodeSignal: [ReviewRiskCodeMatch]] = [:]
    /// The languages the app is localized into (`ReviewRiskLanguageCode.base`),
    /// from the project's known regions, *.lproj folders and string catalogs.
    var languages: Set<String> = []
    /// The project's development language, e.g. "en".
    var developmentLanguage = "en"
    /// Swift files read; none means the checks can't tell.
    var swiftFileCount = 0
    /// The folder has more Swift files than Atlas reads.
    var reachedFileLimit = false

    init(folderName: String, packages: Set<String> = [], imports: Set<String> = [], entitlements: Set<String> = []) {
        self.folderName = folderName
        self.packages = packages
        self.imports = imports
        self.entitlements = entitlements
    }

    func matches(_ signal: ReviewRiskCodeSignal) -> [ReviewRiskCodeMatch] {
        signals[signal] ?? []
    }

    func uses(_ permission: ReviewRiskPermission) -> [ReviewRiskCodeMatch] {
        permissionUses[permission] ?? []
    }

    /// The permission text that covers `permission`, written, if any.
    func purposeString(for permission: ReviewRiskPermission) -> ReviewRiskPurposeString? {
        permission.keys.lazy.compactMap { purposeStrings[$0] }.first(where: \.isWritten)
    }

    /// Keeps `match` under its target, once per line and at most
    /// `matchLimit` each.
    mutating func add(_ match: ReviewRiskCodeMatch, for target: ReviewRiskCodeTarget) {
        switch target {
        case let .signal(signal):
            var list = signals[signal] ?? []
            guard list.count < Self.matchLimit, !list.contains(where: { $0.file == match.file && $0.line == match.line }) else { return }
            list.append(match)
            signals[signal] = list
        case let .permission(permission):
            var list = permissionUses[permission] ?? []
            guard list.count < Self.matchLimit, !list.contains(where: { $0.file == match.file && $0.line == match.line }) else { return }
            list.append(match)
            permissionUses[permission] = list
        }
    }
}
