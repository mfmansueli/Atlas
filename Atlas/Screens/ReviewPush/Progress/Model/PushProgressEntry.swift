//
//  PushProgressEntry.swift
//  Atlas
//

import Foundation

/// One row of a push as the progress sheet counts it: a change, a
/// screenshot, an extra or an event's art. `id` is the row's, prefixed by
/// where it comes from (`change.`, `shot.`, `extra.`), so the three never
/// clash; the viewer uses the same IDs.
struct PushProgressEntry: Hashable, Sendable, Identifiable {
    var id: String
    /// "Subtitle · English (U.S.)", "Arabic · iPhone · 1".
    var title: String
    var kind: PushProgressKind
    var state: PushProgressState
}
