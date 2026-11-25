//
//  PriceTestSetup.swift
//  Atlas
//

import Foundation

/// The Test a Price sheet as the person fills it in: the product, the
/// region, the step, the comparison and the subscriber choice, then the
/// confirmation.
struct PriceTestSetup: Hashable, Sendable {
    var productID: String
    var region: TerritoryRegion?
    var step = PriceTestStep.percent(-20)
    var control = PriceTestControlChoice.automatic
    /// People who pay a lower test price keep it afterward.
    var keepsTestPrice = true
    /// Continue was pressed: the level-3 confirmation shows.
    var isConfirming = false
    /// The assistant's card it came from, which goes once the test is queued.
    var suggestionID: PriceTestSuggestion.ID?
    var suggestedBy: String?
}
