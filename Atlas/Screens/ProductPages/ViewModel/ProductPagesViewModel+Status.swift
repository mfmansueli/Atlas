//
//  ProductPagesViewModel+Status.swift
//  Atlas
//

import Foundation

// Where a page stands with App Review (board 54's banners): waiting (and
// Cancel Submission), in review, approved (Edit… makes a new version),
// rejected (the reviewer's message is only in App Store Connect), or a new
// version being prepared beside the approved one.
extension ProductPagesViewModel {
    /// An approved page with a new version on the way: one being prepared
    /// in App Store Connect, or Edit… pressed here.
    func isPreparingNewVersion(_ page: ProductPage) -> Bool {
        guard page.approved != nil, !page.isDraft else { return false }
        if let next = page.nextVersion { return next.state.isEditable }
        return editingApprovedPageIDs.contains(page.id) || !edits(of: page).isEmpty
    }

    func statusNote(of page: ProductPage) -> ProductPageStatusNote? {
        guard !page.isDraft, let editing = page.editing else { return nil }
        let visibleLater = makesVisibleWhenApproved(page)
            ? " " + String(localized: "It becomes visible once it’s approved, as you chose.") : ""
        switch editing.state {
        case .waitingForReview:
            let canCancel = canCancelSubmission(of: page)
            let message = canCancel
                ? String(localized: "App Review usually answers within a day. The page can’t be edited while it waits; cancel the submission to change it.")
                : String(localized: "App Review usually answers within a day. The page can’t be edited while it waits.")
            return ProductPageStatusNote(
                tone: .waiting, title: String(localized: "Waiting for Review."), message: message + visibleLater,
                action: canCancel ? .cancelSubmission : nil
            )
        case .inReview:
            return ProductPageStatusNote(
                tone: .waiting, title: String(localized: "In Review."),
                message: String(localized: "Nothing can be changed or cancelled until App Review answers.") + visibleLater
            )
        case .rejected:
            return ProductPageStatusNote(
                tone: .problem, title: String(localized: "Rejected by App Review."),
                message: String(localized: """
                App Store Connect’s API doesn’t give Atlas the reviewer’s message, so it isn’t shown here. Read it in App Store \
                Connect, under App Review, then fix the page and submit again.
                """),
                action: .openAppStoreConnect
            )
        case .prepareForSubmission, .readyForReview, .accepted, .approved, .replacedWithNewVersion:
            return approvedNote(page)
        }
    }

    private func approvedNote(_ page: ProductPage) -> ProductPageStatusNote? {
        guard let approved = page.approved else { return nil }
        if isPreparingNewVersion(page) {
            let next = page.nextVersion?.number ?? approved.number + 1
            return ProductPageStatusNote(
                tone: .fine,
                title: String(localized: "Version \(approved.number) stays on the App Store while you prepare version \(next)."),
                message: String(localized: "People see the approved one until App Review approves the new one.")
            )
        }
        if isVisible(page) {
            return ProductPageStatusNote(
                tone: .fine, title: String(localized: "On the App Store, and visible."),
                message: String(localized: "Editing makes a new version. People keep seeing this one until the new one is approved."),
                action: canChange ? .edit : nil
            )
        }
        return ProductPageStatusNote(
            tone: .fine, title: String(localized: "Approved, and hidden."),
            message: String(localized: """
            Its link opens the default page while it is hidden. Turn Visible on to bring it back; that needs no review.
            """),
            action: canChange ? .edit : nil
        )
    }

    /// Where App Review's message about the page is.
    var appStoreConnectURL: URL {
        URL(string: "https://appstoreconnect.apple.com/apps/\(app.id)/distribution") ?? URL(filePath: "/")
    }
}
