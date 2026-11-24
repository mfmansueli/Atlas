//
//  WorkspaceServices.swift
//  Atlas
//

import Foundation

/// Every feature's services for one connected account, handed from
/// `MainView` down to the sections. `live(client:)` talks to App Store
/// Connect; DEBUG scenes and previews build one from fakes.
@MainActor
struct WorkspaceServices {
    var appList: any AppListServices
    var pricing: any PricingServices
    var storePage: any StorePageServices
    var appInformation: any AppInformationServices
    /// Pricing → Retention: retention messages and offers.
    var retention: any RetentionServices
    /// Pricing's App Price and Availability: the app's own price schedule
    /// and the countries and regions it's sold in.
    var appPriceAvailability: any AppPriceAvailabilityServices
    /// Analytics: Apple's analytics reports and Sales and Trends.
    var analytics: any AnalyticsServices
    /// Reviews: App Store reviews, the replies and the ratings.
    var reviews: any ReviewsServices
    /// The version's way to the App Store: submitting and releasing.
    var release: any ReleaseServices
    /// In-App Events and their texts in every language.
    var inAppEvents: any InAppEventsServices
    /// Custom product pages, and the default page they start from.
    var productPages: any ProductPagesServices
    /// Featuring nominations, and what Atlas suggests them from.
    var nominations: any NominationsServices
    /// Where Review & Push sends writes.
    var push: any PushTransport

    /// Screenshots; they come with the store page's services.
    var screenshots: any ScreenshotsServices { storePage.screenshots }

    static func live(client: AppStoreConnectClient) -> WorkspaceServices {
        WorkspaceServices(
            appList: LiveAppListServices(client: client),
            pricing: LivePricingServices(client: client),
            storePage: LiveStorePageServices(client: client),
            appInformation: LiveAppInformationServices(client: client),
            retention: LiveRetentionServices(client: client),
            appPriceAvailability: LiveAppPriceAvailabilityServices(client: client),
            analytics: LiveAnalyticsServices(client: client),
            reviews: LiveReviewsServices(client: client),
            release: LiveReleaseServices(client: client),
            inAppEvents: LiveInAppEventsServices(client: client),
            productPages: LiveProductPagesServices(client: client),
            nominations: LiveNominationsServices(client: client),
            push: client
        )
    }
}
