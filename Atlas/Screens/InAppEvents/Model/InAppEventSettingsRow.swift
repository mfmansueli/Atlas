//
//  InAppEventSettingsRow.swift
//  Atlas
//

import Foundation

/// One row of the event page's Event card: its badge, its dates, from
/// when it shows and where. A date that has passed before App Review
/// approved the event is a problem ("Was set to show from Nov 19 at 12:00
/// AM (your time), which has passed"), with Fix… on the date to change
/// while the event can still change.
struct InAppEventSettingsRow: Identifiable, Hashable, Sendable {
    var title: String
    var value: String
    var isProblem = false
    /// The date Fix… goes to; nil for no Fix….
    var fixField: InAppEventDateField?

    var id: String { title }

    /// `events.settings.<this>`: "badge", "dates", "publish", "territories".
    var key = ""
}
