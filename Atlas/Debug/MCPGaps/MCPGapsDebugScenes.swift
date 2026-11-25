//
//  MCPGapsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// DEBUG scenes (`-AtlasDebugScene <id>`) for what assistants can now
/// suggest over MCP that waits on a section's page:
///
/// - `pr-strategy`: Lumen's product cards with a pricing strategy Claude
///   Code suggested (`propose_pricing_strategy`): Europe at 90% as
///   regional tiers, waiting at the top of Pricing.
/// - `rv-replace`: Reviews, Replied, with a new text Claude Code
///   suggested for the reply the British review already has
///   (`propose_review_replies` with replace).
enum MCPGapsDebugScenes {
    typealias AppIDs = DebugFixtures.AppID

    static let ids = ["pr-strategy", "rv-replace"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-strategy": pricingStrategy
        case "rv-replace": reviewReplacement
        default: nil
        }
    }

    // MARK: - Pricing

    /// Europe at 90% of the US price, as regional tiers.
    static var strategySuggestion: PricingStrategySuggestion {
        var strategy = PricingStrategy.recommended
        strategy.customize { $0.method = .regionalTiers }
        strategy.regionMultipliers[.europe] = Decimal(90) / 100
        strategy.regionMultipliers[.asiaPacific] = Decimal(75) / 100
        return PricingStrategySuggestion(
            id: "ps-debug", mode: nil, strategy: strategy, title: "Price Europe at 90% of the US",
            why: "Europe converts at 4.1%, close to the US’s 4.4%: deeper discounts there gain little.",
            layers: SuggestionLayers(
                details: "Analytics, last 90 days: Europe 4.1% (2,140 downloads), the US 4.4%, Asia Pacific 2.6%.", confidence: .fairlySure
            ),
            source: DebugReviewsData.client, receivedAt: DebugReviewsData.today
        )
    }

    @MainActor
    private static var pricingStrategy: AnyView {
        var services = WorkspaceServices.debug
        services.pricing = DebugPricingServices(launch: PricingDebugLaunch(showsProducts: true, strategySuggestion: strategySuggestion))
        return AnyView(DebugMainScene(
            services: services, selectedAppID: AppIDs.lumen, section: .subscriptionPricing, pushRecords: DebugWorkspace.pushRecords,
            pricingModes: DebugWorkspace.pricingModes
        ))
    }

    // MARK: - Reviews

    /// The British review's reply promised PDF export in 1.5; the new text
    /// says when.
    static let replacementText = "Thanks! PDF export is in 1.5, out this week: Settings → Export → Year as PDF."

    @MainActor
    private static var reviewReplacement: AnyView {
        var archive = DebugReviewsData.archive
        if let review = archive.review(id: "r-gb1") {
            archive.suggestions[review.id] = ReviewReplySuggestion(
                reviewID: review.id, text: replacementText, meaning: "", source: DebugReviewsData.client, date: DebugReviewsData.today,
                layers: SuggestionLayers(confidence: .sure), replaces: review.reply,
                why: "Your reply says PDF export is coming; 1.5 has it, out this week."
            )
        }
        return ReviewsDebugScenes.scene(store: DebugReviewsData.store(archive: archive), launch: ReviewsDebugLaunch(filter: .replied))
    }
}
#endif
