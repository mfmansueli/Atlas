//
//  ProductPageNotConfirmed.swift
//  Atlas
//

import Foundation

/// A new custom product page Apple failed on (a 5xx or no answer) that
/// Atlas couldn't find ready after looking for it: it may still be made, so
/// it isn't made again now. A retry looks for it first and goes on with it.
struct ProductPageNotConfirmed: LocalizedError, Equatable {
    var name: String
    /// Apple's code and detail, or that it didn't answer; nil when this
    /// send didn't fail (a retry that found the page not ready yet).
    var appleText: String?
    /// The page was listed, but without a version that takes edits yet.
    var pageSeen: Bool
    var looked: Duration

    init(name: String, error: (any Error)?, pageSeen: Bool, looked: Duration) {
        self.name = name
        self.pageSeen = pageSeen
        self.looked = looked
        appleText = error.map(Self.appleText)
    }

    var errorDescription: String? {
        let apple = appleText.map { ($0.hasSuffix(".") ? $0 : $0 + ".") + " " } ?? ""
        if pageSeen {
            return apple + String(localized: """
            Apple is still making “\(name)”. Retry in a few minutes; Atlas continues with that page, not a new one.
            """)
        }
        let time = looked.formatted(.units(allowed: [.minutes, .seconds], width: .wide))
        return apple + String(localized: """
        “\(name)” isn’t in App Store Connect after \(time); Apple may still be making it. Retry in a few minutes. \
        Atlas won’t make a duplicate.
        """)
    }

    static func appleText(_ error: any Error) -> String {
        if let error = error as? AppStoreConnectError { return error.pushFailureText }
        if let error = error as? URLError, error.code == .timedOut { return String(localized: "Apple didn’t answer in time.") }
        return error.localizedDescription
    }
}
