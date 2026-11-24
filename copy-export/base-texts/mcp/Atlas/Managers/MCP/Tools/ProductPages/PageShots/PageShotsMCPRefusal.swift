//
//  PageShotsMCPRefusal.swift
//  Atlas
//

import Foundation

/// Why a page screenshot tool can't act on the page it was given.
struct PageShotsMCPRefusal: Error {
    var target: String
    var message: String

    var outcome: MCPToolOutcome { .refused(message, target: target) }
}
