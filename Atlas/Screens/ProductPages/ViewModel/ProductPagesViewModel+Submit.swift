//
//  ProductPagesViewModel+Submit.swift
//  Atlas
//

import Foundation

// Push and Submit… (board 54): a page's changes go through Review & Push
// first, then the page goes to App Review by itself. Only the person
// submits; an assistant can't. "Make the page visible when it's approved"
// is kept on this Mac and, once Apple approves the page, turning Visible on
// waits in Review & Push.
extension ProductPagesViewModel {
    // MARK: - What can go

    /// The version Submit for Review sends: one in App Store Connect that
    /// can go to App Review, with nothing of the page left to push.
    func submittableVersion(of page: ProductPage) -> ProductPageVersion? {
        guard !page.isDraft, pendingCount(of: page) == 0, let version = page.editing, !version.id.isEmpty else { return nil }
        switch version.state {
        case .prepareForSubmission, .readyForReview, .rejected: return version
        case .waitingForReview, .inReview, .accepted, .approved, .replacedWithNewVersion: return nil
        }
    }

    /// The header's button: "Submit for Review…" (board 57). While the
    /// page has changes to push (a draft always does) it opens Review &
    /// Push on the page first, and Submit for Review after the push; nil
    /// while it's with App Review or approved and untouched.
    func primaryActionTitle(of page: ProductPage) -> String? {
        guard canChange, !isLocked(page) else { return nil }
        if page.isDraft || pendingCount(of: page) > 0 {
            return canPushAndSubmit(page) ? String(localized: "Submit for Review…") : nil
        }
        return submittableVersion(of: page) == nil ? nil : String(localized: "Submit for Review…")
    }

    /// The header's button pressed. Returns whether Review & Push should
    /// open: the page's changes are pushed there, and Submit for Review
    /// opens here when that's done.
    func pushAndSubmit(_ page: ProductPage) -> Bool {
        if page.isDraft || pendingCount(of: page) > 0 {
            submitsAfterPushPageName = page.name
            return true
        }
        if submittableVersion(of: page) != nil {
            submitError = nil
            isSubmitPresented = true
        }
        return false
    }

    /// A push finished: reads the pages again and, when Push and Submit…
    /// started it and the page is pushed, opens Submit for Review.
    func didPush(failures: [String] = []) async {
        if failures.contains(where: Self.isForbidden) { store.setKeyCannotChange(true, for: app.id) }
        await load(force: true)
        guard let name = submitsAfterPushPageName, let page = pages.first(where: { !$0.isDraft && $0.name == name }) else { return }
        guard submittableVersion(of: page) != nil else {
            // Something of it didn't push: it stays in Review & Push.
            if pendingCount(of: page) == 0 { submitsAfterPushPageName = nil }
            return
        }
        submitsAfterPushPageName = nil
        selectedPageID = page.id
        submitError = nil
        isSubmitPresented = true
    }

    /// App Store Connect's answer to a key whose role can't change pages.
    static func isForbidden(_ message: String) -> Bool {
        guard let refused = AppStoreConnectError.forbidden(detail: nil).errorDescription else { return false }
        return message.hasPrefix(refused)
    }

    // MARK: - Submitting

    /// Sends the page's version to App Review by itself. The choice of
    /// making it visible once approved is kept on this Mac.
    func submit(_ page: ProductPage, makeVisible: Bool) async {
        guard let version = submittableVersion(of: page), !isSubmitting, canChange else { return }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            try await services.submit(versionID: version.id, of: app)
            store.setVisibleWhenApproved(makeVisible && !page.isVisible, pageID: page.id, for: app.id)
            store.followReview(versionID: version.id, state: .waitingForReview, for: app.id)
            setState(.waitingForReview, ofVersion: version.id, pageID: page.id)
            isSubmitPresented = false
            show(String(localized: "“\(page.name)” was submitted to App Review."), undo: nil)
        } catch {
            if case AppStoreConnectError.forbidden = error { store.setKeyCannotChange(true, for: app.id) }
            submitError = AppleErrorCopy(String(localized: "The page wasn’t submitted.", comment: "kind:error"), error: error)
        }
    }

    /// Cancel Submission shows while the page waits and App Store Connect
    /// can take it back.
    func canCancelSubmission(of page: ProductPage) -> Bool {
        services.canCancelSubmission && canChange && !isOffline && page.editing?.state == .waitingForReview
    }

    /// Takes the page back from App Review while it waits.
    func cancelSubmission(of page: ProductPage) async {
        guard canCancelSubmission(of: page), let version = page.editing, !isCancellingSubmission else { return }
        isCancellingSubmission = true
        defer { isCancellingSubmission = false }
        do {
            try await services.cancelSubmission(versionID: version.id, of: app)
            store.setVisibleWhenApproved(false, pageID: page.id, for: app.id)
            store.followReview(versionID: version.id, state: .prepareForSubmission, for: app.id)
            setState(.prepareForSubmission, ofVersion: version.id, pageID: page.id)
            show(String(localized: "Submission cancelled. The page is back to Prepare for Submission."), undo: nil)
        } catch {
            let text = (error as? ProductPageSubmissionError)?.errorDescription
                ?? AppleErrorCopy(String(localized: "The submission wasn’t canceled.", comment: "kind:error"), error: error).text
            show(text, undo: nil)
        }
    }

    /// What App Store Connect says now, without reading it again.
    private func setState(_ newState: ProductPageState, ofVersion versionID: String, pageID: ProductPage.ID) {
        guard var snapshot,
              let pageIndex = snapshot.pages.firstIndex(where: { $0.id == pageID }),
              let versionIndex = snapshot.pages[pageIndex].versions.firstIndex(where: { $0.id == versionID }) else { return }
        snapshot.pages[pageIndex].versions[versionIndex].state = newState
        replaceSnapshot(snapshot)
    }

    // MARK: - App Review's answer

    /// What App Review did with the pages since the last read: a toast
    /// here and a notification (`AtlasNotifications.productPagesMoved`).
    /// A read in the background (`MainWindowBackground`) tells it first,
    /// and then there's nothing left to tell here.
    func tellReviewMoves(in snapshot: ProductPagesSnapshot) {
        let moves = store.followReview(of: snapshot.pages, for: app.id)
        let told = AtlasNotifications.productPagesMoved(moves, appName: app.name, appID: app.id)
        guard let first = told.first else { return }
        let text = told.count == 1 ? first : String(localized: "App Review moved \(told.count) custom product pages.")
        toast = ToastMessage(text: text)
    }

    // MARK: - Visible when approved

    /// Pages submitted with "Make the page visible when it's approved":
    /// once Apple approved the version, turning Visible on waits in Review &
    /// Push (it needs no review). A rejected one forgets the choice.
    func queueVisibleWhenApproved() {
        let flagged = store.archive(for: app.id).visibleWhenApproved
        guard !flagged.isEmpty, let snapshot else { return }
        var approved: [String] = []
        for page in snapshot.pages where flagged.contains(page.id) {
            if page.state.isApproved, page.nextVersion == nil {
                store.setVisibleWhenApproved(false, pageID: page.id, for: app.id)
                guard !page.isVisible, let change = builder.visibleChange(true, of: page, source: .you) else { continue }
                queue.upsert(change)
                approved.append(page.name)
            } else if page.editing?.state == .rejected {
                store.setVisibleWhenApproved(false, pageID: page.id, for: app.id)
            }
        }
        guard let first = approved.first else { return }
        let text = approved.count == 1
            ? String(localized: "Apple approved “\(first)”. Turning Visible on is in Review & Push, as you asked.")
            : String(localized: "Apple approved \(approved.count) pages. Turning Visible on is in Review & Push, as you asked.")
        toast = ToastMessage(text: text, actionTitle: String(localized: "Review & Push"))
    }

    /// Whether the page was submitted to be made visible once approved.
    func makesVisibleWhenApproved(_ page: ProductPage) -> Bool {
        store.archive(for: app.id).visibleWhenApproved.contains(page.id)
    }
}
