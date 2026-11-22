//
//  AppPriceDebugSheet.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The App Price and Availability sheet a DEBUG scene opens with.
enum AppPriceDebugSheet: Hashable, Sendable {
    case price
    case availability
}
#endif
