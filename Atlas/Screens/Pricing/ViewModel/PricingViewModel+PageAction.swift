//
//  PricingViewModel+PageAction.swift
//  Atlas
//

import Foundation

/// Add Subscription… in the toolbar (board 80).
extension PricingViewModel {
    /// Off until the app's products are read: the sheet offers their groups.
    var pageActionState: WorkspacePageActionState {
        catalog != nil ? .enabled : .disabled(reason: nil)
    }

    /// Create Subscription's sheet, from Prices (Retention doesn't show it).
    func startPageAction() {
        guard pageActionState.isEnabled else { return }
        page = .prices
        isNewSubscriptionSheetPresented = true
    }
}
