//
//  NewAppVersion.swift
//  Atlas
//

import Foundation

/// An App Store version to create in App Store Connect: its number and its
/// platform. App Store Connect makes it in Prepare for Submission, and the
/// Store Page then edits its texts.
struct NewAppVersion: Hashable, Codable, Sendable {
    var versionString: String
    /// App Store Connect's platform, e.g. `IOS` or `MAC_OS`.
    var platform: String

    init(versionString: String, platform: String) {
        self.versionString = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.platform = platform
    }

    /// "iOS", or the raw platform when there's no name for it here.
    var platformTitle: String {
        StorePageVersion.title(ofPlatform: platform) ?? platform
    }

    /// "1.4" after "1.3", "2.0.1" after "2.0.0": the last number plus one.
    static func next(after version: String) -> String {
        var parts = version.split(separator: ".").map(String.init)
        guard let last = parts.last, let number = Int(last) else { return version }
        parts[parts.count - 1] = String(number + 1)
        return parts.joined(separator: ".")
    }

    /// What App Store Connect takes: one to three whole numbers separated
    /// by periods, e.g. 2, 1.4 or 2.0.1.
    static func isWellFormed(_ version: String) -> Bool {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        return (1...3).contains(parts.count) && parts.allSatisfy { part in !part.isEmpty && part.allSatisfy { $0.isASCII && $0.isNumber } }
    }

    /// Compares number by number, so 1.10 is higher than 1.9 and 2 equals
    /// 2.0.
    static func isHigher(_ version: String, than other: String) -> Bool {
        let lhs = numbers(version)
        let rhs = numbers(other)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func numbers(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
