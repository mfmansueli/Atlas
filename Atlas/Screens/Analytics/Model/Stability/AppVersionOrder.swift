//
//  AppVersionOrder.swift
//  Atlas
//

import Foundation

/// Orders app versions as people read them: 1.10 after 1.9.
enum AppVersionOrder {
    static func isBefore(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedAscending
    }
}
