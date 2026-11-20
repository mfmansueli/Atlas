//
//  ProductPageStatusNote.swift
//  Atlas
//

import Foundation

/// The banner at the top of a page's editor: where it stands with App
/// Review, and what can be done from here.
struct ProductPageStatusNote: Hashable, Sendable {
    enum Tone: Hashable, Sendable {
        /// With App Review.
        case waiting
        /// Approved, or a new version being prepared beside it.
        case fine
        /// Rejected.
        case problem
    }

    enum Action: Hashable, Sendable {
        case cancelSubmission
        /// Edit… on an approved page: a new version.
        case edit
        /// Where the reviewer's message is.
        case openAppStoreConnect
    }

    var tone: Tone
    var title: String
    var message: String
    var action: Action?
}
