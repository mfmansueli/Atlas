//
//  QueuedVersionPushOrder.swift
//  Atlas
//

import Foundation

/// A new version's texts go after everything else, so the version they go
/// into is created first: they're `ordered` (`PushSchedule`), and wait for
/// it like for every earlier ordered change of their app.
enum QueuedVersionPushOrder {
    static func sorted(_ changes: [PendingChange]) -> [PendingChange] {
        changes.filter { $0.dependsOn == nil } + changes.filter { $0.dependsOn != nil }
    }
}
