//
//  AutopilotCaptureTarget+Key.swift
//  Atlas
//

import Foundation

extension AutopilotCaptureTarget {
    /// One string for the target, to key what's chosen for it:
    /// "today|iphone|ja", "week|iphone_duo|ja|closed".
    var key: String {
        let parts = [screenID, displayType.mcpValue, locale] + (duoPose.map { [$0.rawValue] } ?? [])
        return parts.joined(separator: "|")
    }
}
