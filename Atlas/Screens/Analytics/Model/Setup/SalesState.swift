//
//  SalesState.swift
//  Atlas
//

import Foundation

/// Whether Sales and Trends (trials, paid starts, proceeds) can be read.
enum SalesState: Hashable, Sendable {
    case ready
    /// The vendor number hasn't been typed in.
    case needsVendorNumber
    /// The key's role can't read sales (App Manager, Developer…).
    case keyCannotRead
    /// Readable, but nothing has been downloaded yet.
    case waiting
}
