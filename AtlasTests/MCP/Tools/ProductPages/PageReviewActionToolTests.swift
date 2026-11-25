//
//  PageReviewActionToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_page_review_action`'s refusals: each action only where the
/// page's own button would be there. The person presses it.
@MainActor
@Suite("Product page review actions over MCP")
struct PageReviewActionToolTests {
    private let draft = ProductPage(id: "draft", name: "Private Diary", url: nil, isVisible: false, versions: [], isDraft: true)

    @Test func aDraftCanBeSubmittedButNotCancelledOrVersioned() {
        #expect(ProposePageReviewActionTool.refusal(.submit, page: draft, canCancel: true) == nil)
        #expect(ProposePageReviewActionTool.refusal(.cancelSubmission, page: draft, canCancel: true)?.contains("isn’t Waiting for Review") == true)
        #expect(ProposePageReviewActionTool.refusal(.newVersion, page: draft, canCancel: true)?.hasPrefix("Only an approved page") == true)
    }

    @Test func anApprovedPageStartsANewVersionBeforeItsSubmitted() throws {
        let page = try #require(DebugProductPagesData.pages.first { $0.editing?.state.isApproved == true && $0.nextVersion == nil })
        #expect(ProposePageReviewActionTool.refusal(.newVersion, page: page, canCancel: true) == nil)
        #expect(ProposePageReviewActionTool.refusal(.submit, page: page, canCancel: true)?.contains("Suggest newVersion first") == true)
    }

    @Test func cancellingNeedsAPageWaitingForReviewAndTheAPI() {
        guard let page = DebugProductPagesData.pages.first(where: { $0.editing?.state == .waitingForReview }) else { return }
        #expect(ProposePageReviewActionTool.refusal(.cancelSubmission, page: page, canCancel: true) == nil)
        #expect(ProposePageReviewActionTool.refusal(.cancelSubmission, page: page, canCancel: false)?.contains("API") == true)
        #expect(ProposePageReviewActionTool.refusal(.submit, page: page, canCancel: true)?.contains("with App Review already") == true)
    }
}
#endif
