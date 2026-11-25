//
//  PricingSalesInput+Store.swift
//  Atlas
//

import Foundation

@MainActor
extension PricingSalesInput {
    /// `appID`'s facts as the store has them now.
    init(store: AnalyticsStore, appID: StoreApp.ID, usesSalesData: Bool) {
        self.init(
            engagement: store.archive(for: appID).facts,
            events: store.sales.events.filter { $0.appID == appID },
            subscribers: store.sales.subscribers.filter { $0.appID == appID },
            active: store.sales.active.filter { $0.appID == appID },
            salesDays: store.sales.days,
            salesState: store.salesState,
            usesSalesData: usesSalesData
        )
    }
}
