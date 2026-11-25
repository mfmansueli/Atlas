//
//  QueuedCountryPrice.swift
//  Atlas
//

import Foundation

/// A country's price as it waits in Review & Push, read back from the
/// queue: what it becomes, whether that's Apple's automatic price, and who
/// set it.
struct QueuedCountryPrice: Hashable, Sendable {
    var price: Decimal
    var isAutomatic: Bool
    var source: ChangeSource
}
