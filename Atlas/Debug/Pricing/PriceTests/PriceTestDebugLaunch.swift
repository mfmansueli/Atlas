//
//  PriceTestDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// What a price test DEBUG scene opens with.
struct PriceTestDebugLaunch {
    var state = PriceTestDebugState.none
    /// Each country's 28 days: board 76's numbers, Europe 2,140 page views
    /// and 96 starts, Africa & Middle East 12 starts.
    var signals = DebugPriceTests.signals
}
#endif
