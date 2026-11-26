//
//  AppInformationViewModel+PageStrip.swift
//  Atlas
//

import Foundation

// The page strip (board 88): each page's card status, what only the person
// can give there, the pages' one-line summaries and their unpushed changes.
extension AppInformationViewModel {
    /// The page's card: suggested, needs you or ready (`AppInformationPageStatus`).
    func pageStatus(for page: AppInformationPage) -> AppInformationPageStatus {
        let suggested = suggestionCount(on: page)
        switch page {
        case .accessibility:
            let failed = accessibility.errorMessage != nil
            return AppInformationPageStatus(isLoaded: accessibility.value != nil, hasFailed: failed, suggested: suggested, needsYou: 0)
        case .appCompliance:
            // The report needs the pages and where the app is sold.
            let failed = compliance.errorMessage != nil || errorMessage != nil
            return AppInformationPageStatus(isLoaded: complianceReport != nil, hasFailed: failed, suggested: suggested, needsYou: needsYouCount(on: page))
        case .appPrivacy:
            // The worksheet is on this Mac: always there.
            return AppInformationPageStatus(isLoaded: true, suggested: suggested, needsYou: needsYouCount(on: page))
        case .general, .ageRating, .appReview, .exportCompliance:
            return AppInformationPageStatus(isLoaded: isLoaded, hasFailed: errorMessage != nil, suggested: suggested, needsYou: needsYouCount(on: page))
        }
    }

    /// What only the person can give on `page` (`AppInformationNeedsYou`).
    func needsYouCount(on page: AppInformationPage) -> Int {
        switch page {
        case .general:
            guard let general else { return 0 }
            let asksCopyright = content?.version != nil && content?.isVersionEditable == true
            return AppInformationNeedsYou.general(general, asksCopyright: asksCopyright)
        case .appCompliance:
            return complianceReport.map(AppInformationNeedsYou.compliance) ?? 0
        case .ageRating:
            return unansweredCount(on: .ageRating)
        case .accessibility:
            return 0
        case .appPrivacy:
            let worksheet = privacy.worksheet
            return AppInformationNeedsYou.privacy(status: worksheet.status, openQuestions: worksheet.openQuestions.count, unreviewed: worksheet.unreviewedCount)
        case .appReview:
            guard isReviewEditable, let review else { return 0 }
            return AppInformationNeedsYou.review(review)
        case .exportCompliance:
            return exportAnswers.map(AppInformationNeedsYou.export) ?? 0
        }
    }

    /// Age Rating's questions without an answer.
    func unansweredCount(on page: AppInformationPage) -> Int {
        guard page == .ageRating, isLoaded else { return 0 }
        return AgeRatingQuestion.allCases.count { suggestionValue(.ageRating($0)).isEmpty }
    }

    /// e.g. "Lifestyle · Health & Fitness", "9+", "1 published · 1 not
    /// declared", "In progress", "Complete", "Exempt"; nil while loading.
    /// App Privacy's comes from the worksheet on this Mac.
    func status(for page: AppInformationPage) -> String? {
        switch page {
        case .general: general.map { $0.categorySummary.isEmpty ? String(localized: "No category") : $0.categorySummary }
        case .appCompliance: complianceReport?.status
        case .ageRating: ratingPreview?.effective.title
        case .accessibility: accessibilityStatus
        case .appPrivacy: privacy.status.title
        case .appReview: review.map { $0.isComplete ? String(localized: "Complete") : String(localized: "Missing details") }
        case .exportCompliance: exportAnswers?.status
        }
    }

    /// Whether the page has changes waiting in Review & Push.
    /// App Privacy counts the Privacy Policy URLs it edits, which are
    /// Store Page's changes.
    func hasPendingChanges(on page: AppInformationPage) -> Bool {
        let builder = builder
        if changes.contains(where: { builder.page(of: $0) == page }) { return true }
        // Stopping sales in China mainland shares Pricing's id.
        if page == .appCompliance, builder.stopsSelling(in: ComplianceRegion.chinaMainland, with: queue.changes(for: app.id)) { return true }
        guard page == .appPrivacy else { return false }
        let prefix = "storePage.\(app.id).appInfo."
        let suffix = ".\(ListingField.privacyPolicyURL.rawValue)"
        return queue.changes(for: app.id, section: .storePage).contains { $0.id.hasPrefix(prefix) && $0.id.hasSuffix(suffix) }
    }

    private var accessibilityStatus: String? {
        switch accessibility {
        case .idle, .loading: return nil
        case .failed: return String(localized: "Couldn’t load")
        case .loaded:
            let cards = accessibilityCards
            let published = cards.count(where: \.isPublished)
            let notDeclared = cards.count { $0.state == .notDeclared }
            return String(localized: "\(published) published · \(notDeclared) not declared")
        }
    }
}
