//
//  ProductPageReviewAction.swift
//  Atlas
//

import Foundation

/// What an assistant can suggest doing with a page and App Review: send it
/// (Submit for Review…), take it back while it waits (Cancel Submission),
/// or start a new version of an approved page (Edit…).
enum ProductPageReviewAction: String, CaseIterable, Hashable, Sendable {
    case submit
    case cancelSubmission
    case newVersion

    /// The button the person presses on the page, by its title.
    var buttonTitle: String {
        switch self {
        case .submit: String(localized: "Submit for Review…")
        case .cancelSubmission: String(localized: "Cancel Submission")
        case .newVersion: String(localized: "Edit…")
        }
    }
}
