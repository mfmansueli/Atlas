//
//  PushSideBySideKey.swift
//  Atlas
//

import Foundation

/// What a change creates when it's one of many similar creates a push
/// sends side by side (`PushSchedule`), rather than in its app's order.
/// Two changes with the same key still go one after the other; different
/// keys never touch the same resource:
/// - one territory's subscription price (`POST /v1/subscriptionPrices`,
///   `PriceChangeFactory`): by subscription and territory;
/// - a new Store Page language (`POST /v1/appStoreVersionLocalizations` or
///   `/v1/appInfoLocalizations` with no placeholder): by app and locale, so
///   a language's app and version pages keep their order;
/// - a new In-App Texts language into the owner's draft
///   (`InAppDraftWrite`): by owner and locale; the push finds or makes the
///   draft once for all of them (`PushSlots`);
/// - a new subscription (`NewSubscriptionChangeBuilder`): by product ID;
///   its group is found or made once for all of them, and its own steps
///   still go in order;
/// - an existing subscription's starting price: by subscription.
enum PushSideBySideKey {
    /// The key, or nil when the change keeps its app's order.
    static func of(_ change: PendingChange) -> String? {
        let requests = change.pushRequests
        guard change.mergeKey == nil, change.dependsOn == nil, !requests.isEmpty else { return nil }
        if NewSubscriptionChangeBuilder.owns(change), change.creation != nil,
           let productID = NewSubscriptionChangeBuilder.productID(of: change)
        {
            return "newSubscription:\(change.appID):\(productID)"
        }
        let keys = Set(requests.map { key(of: $0, appID: change.appID) })
        guard keys.count == 1, let key = keys.first else { return nil }
        return key
    }

    /// One request's key, or nil when it isn't such a create.
    static func key(of request: PushRequest, appID: StoreApp.ID) -> String? {
        guard request.method == .post else { return nil }
        if let prices = SubscriptionStartingPrices(request), !prices.subscriptionID.contains("{") {
            return "startingPrices:\(prices.subscriptionID)"
        }
        if let write = InAppDraftWrite(request), !write.ownerID.contains("{") {
            return "\(write.localizationType):\(write.ownerKey):\(write.locale)"
        }
        guard !PushSchedule.hasPlaceholder(request), let body = request.body else { return nil }
        if request.path == "/v1/subscriptionPrices",
           let price = try? JSONDecoder().decode(SubscriptionPriceCreateRequest.self, from: body)
        {
            let relationships = price.data.relationships
            return "subscriptionPrices:\(relationships.subscription.data.id):\(relationships.territory.data.id)"
        }
        if storeLocalizationPaths.contains(request.path),
           let document = StorePageWriteDocument.decode(body), let locale = document.attribute("locale")
        {
            return "storeLocale:\(appID):\(locale)"
        }
        return nil
    }

    private static let storeLocalizationPaths: Set<String> = [
        "/v1/\(ListingChangeBuilder.versionLocalizationType)",
        "/v1/\(ListingChangeBuilder.appInfoLocalizationType)",
    ]
}
