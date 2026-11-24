//
//  NominationContext.swift
//  Atlas
//

import Foundation

/// What Atlas knows that a nomination can use, read beside the
/// nominations: the account's apps (for Apps), the version being prepared
/// and its What's New (for the type and description), the app's In-App
/// Events (Link an Event…) and the links Atlas has (the App Store page,
/// approved custom product pages).
struct NominationContext: Hashable, Sendable {
    struct Version: Hashable, Sendable {
        var versionString: String
        /// The app's first version: nothing is on the App Store yet.
        var isFirstVersion: Bool
        /// What's New in the primary language.
        var whatsNew: String
    }

    struct Event: Identifiable, Hashable, Sendable {
        var id: String
        var name: String
        /// "Challenge · Dec 15 – Jan 4".
        var detail: String
        var start: Date?
        var isOver: Bool
        /// The primary language's short description, for the suggested
        /// description.
        var shortDescription: String
    }

    struct KnownLink: Hashable, Sendable {
        /// "App Store page", "Custom product page · Prompts".
        var title: String
        /// "Lumen Journal on the App Store".
        var detail: String
        var url: String
    }

    var apps: [StoreApp] = []
    /// The account's team, e.g. "Northpier Studio", for the Submit sheet.
    var teamName: String?
    /// The store page's languages, for Languages.
    var locales: [String] = []
    var version: Version?
    var events: [Event] = []
    var links: [KnownLink] = []

    /// The App Store page every app has.
    static func appStoreLink(for app: StoreApp) -> KnownLink {
        KnownLink(
            title: String(localized: "App Store page", comment: "kind:field-label"),
            detail: String(localized: "\(app.name) on the App Store", comment: "kind:description"),
            url: "https://apps.apple.com/app/id\(app.id)"
        )
    }
}
