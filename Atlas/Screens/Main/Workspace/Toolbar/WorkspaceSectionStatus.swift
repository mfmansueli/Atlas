//
//  WorkspaceSectionStatus.swift
//  Atlas
//

import Foundation

/// The line under the section's title in the toolbar: what waits in it and
/// how much isn't pushed yet, “32 suggestions · 3 not pushed”. The
/// not-pushed part is a link to Review & Push showing only this section.
struct WorkspaceSectionStatus: Equatable {
    let section: AppWorkspaceSection
    /// Suggestions waiting in the section (Analytics: new findings).
    var waiting = 0
    /// Changes and images of this section queued in Review & Push.
    var notPushed = 0
    /// Overview's own lead: the app and its version, “Lumen Journal · 1.4
    /// not submitted”.
    var lead: String?
    /// What's on in the section, after what waits: “auto-reply on”.
    var note: String?

    /// “32 suggestions”, “12 captions suggested”, “2 new findings”; nil
    /// when nothing waits.
    var waitingText: String? {
        guard waiting > 0 else { return nil }
        let (one, many): (String, String) = switch section {
        case .screenshots: (String(localized: "1 caption suggested"), String(localized: "\(waiting) captions suggested"))
        case .productPages: (String(localized: "1 idea"), String(localized: "\(waiting) ideas"))
        case .inAppEvents: (String(localized: "1 language suggested"), String(localized: "\(waiting) languages suggested"))
        case .reviews: (String(localized: "1 reply suggested"), String(localized: "\(waiting) replies suggested"))
        case .analytics: (String(localized: "1 new finding"), String(localized: "\(waiting) new findings"))
        default: (String(localized: "1 suggestion"), String(localized: "\(waiting) suggestions"))
        }
        return waiting == 1 ? one : many
    }

    /// “3 not pushed”; nil when everything is pushed.
    var notPushedText: String? {
        notPushed > 0 ? String(localized: "\(notPushed) not pushed") : nil
    }

    /// Everything before the link: the lead and what waits; nil when
    /// neither has anything to say.
    var leadingText: String? {
        let parts = [lead, waitingText, note].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The whole line, for VoiceOver and the help tag.
    var text: String {
        let parts = [lead, waitingText, note, notPushedText].compactMap(\.self)
        return parts.isEmpty ? String(localized: "Nothing waiting") : parts.joined(separator: " · ")
    }
}
