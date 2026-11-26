//
//  RefreshText+Announcement.swift
//  Atlas
//

import SwiftUI

@MainActor
extension RefreshText {
    /// Said once, politely (low priority, after what VoiceOver is
    /// reading), when a refresh ends: "Updated from App Store Connect."
    static func announceEnd(from old: RefreshState, to new: RefreshState) {
        guard old.isRefreshing, !new.isRefreshing, let text = RefreshText(now: .now).announcement(new) else { return }
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(announcement).post()
    }
}
