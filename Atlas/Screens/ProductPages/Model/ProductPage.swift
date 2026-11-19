//
//  ProductPage.swift
//  Atlas
//

import Foundation

/// A custom product page: another version of the app's App Store page with
/// a link of its own (`appCustomProductPages`), and its versions. A page
/// made in Atlas and not pushed yet is a draft: it has no link and no ID in
/// App Store Connect.
struct ProductPage: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    /// The page's App Store link, with `?ppid=`; Apple makes it.
    var url: URL?
    var isVisible: Bool
    var versions: [ProductPageVersion]
    /// Made in Atlas, in Review & Push, not in App Store Connect yet.
    var isDraft = false

    /// The newest version: the one being prepared or reviewed, or the
    /// approved one when there's nothing newer.
    var latest: ProductPageVersion? {
        versions.filter { $0.state != .replacedWithNewVersion }.max { $0.number < $1.number }
            ?? versions.max { $0.number < $1.number }
    }

    /// The version people see, once Apple approved one.
    var approved: ProductPageVersion? {
        versions.filter(\.state.isApproved).max { $0.number < $1.number }
    }

    /// A version after the approved one: being prepared, reviewed or
    /// rejected while the approved one stays on the App Store.
    var nextVersion: ProductPageVersion? {
        guard let approved, let latest, latest.number > approved.number else { return nil }
        return latest
    }

    /// The main pill: "Approved" while an approved version shows, else the
    /// newest version's state.
    var state: ProductPageState {
        approved == nil ? latest?.state ?? .prepareForSubmission : .approved
    }

    /// What the editor shows and changes: the version after the approved
    /// one when there is one, else the newest.
    var editing: ProductPageVersion? { nextVersion ?? latest }

    /// The languages of the version being edited.
    var locales: [String] { editing?.locales ?? [] }

    var keywordCount: Int { editing?.keywordCount ?? 0 }

    var deepLink: String { editing?.deepLink ?? "" }

    func localization(_ locale: String) -> ProductPageLocalization? {
        editing?.localization(locale)
    }
}
