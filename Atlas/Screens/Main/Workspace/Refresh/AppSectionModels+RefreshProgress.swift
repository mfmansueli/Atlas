//
//  AppSectionModels+RefreshProgress.swift
//  Atlas
//

import Foundation

extension AppSectionModels {
    /// Whether `section` finished the read Refresh number `refreshCount`
    /// asked for: its stamp says so, or its model ended with an error.
    /// Reviews has no stamp: its read is over once it stops loading.
    /// Nominations keeps no model here, so it never holds a Refresh up.
    func refreshProgress(of section: AppWorkspaceSection, refreshCount: Int) -> RefreshSectionProgress {
        if !needsLoad(section, refreshCount: refreshCount) { return .done }
        switch section {
        case .overview, .analytics:
            return .reading
        case .storePage:
            return Self.progress(isLoading: storePage?.isLoading, error: storePage?.errorMessage)
        case .appInformation:
            return Self.progress(isLoading: appInformation?.isLoading, error: appInformation?.errorMessage)
        case .screenshots:
            return Self.progress(isLoading: screenshots?.isLoading, error: screenshots?.errorMessage)
        case .subscriptionPricing:
            return Self.progress(pricing?.catalogState)
        case .inAppEvents:
            return Self.progress(events?.state)
        case .productPages:
            return Self.progress(productPages?.state)
        case .reviews:
            guard let reviews else { return .done }
            if reviews.isLoading { return .reading }
            return reviews.errorMessage.map(RefreshSectionProgress.failed) ?? .done
        case .nominations:
            return .done
        }
    }

    /// A model with an `isLoading` flag and an error message: failed once
    /// it stopped with an error, else still reading until its stamp says
    /// it's done.
    private static func progress(isLoading: Bool?, error: String?) -> RefreshSectionProgress {
        guard isLoading == false, let error else { return .reading }
        return .failed(error)
    }

    private static func progress(_ state: LoadState<some Any>?) -> RefreshSectionProgress {
        if case let .failed(message) = state { return .failed(message) }
        return .reading
    }
}
