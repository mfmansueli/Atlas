//
//  FindingAction+Section.swift
//  Atlas
//

import Foundation

extension FindingAction {
    /// The section the action opens, where the "From Analytics" bar shows;
    /// nil for the ones that stay inside Analytics.
    var section: AppWorkspaceSection? {
        switch self {
        case .storePage, .inAppTexts: .storePage
        case .screenshots, .screenshotsOnDevice: .screenshots
        case .pricing, .pricingResults, .retention, .offerMessage, .retentionLanguages: .subscriptionPricing
        case .productPage, .pageScreenshots: .productPages
        case .changes, .stability, .billing: nil
        }
    }
}
