//
//  ChangeAlternative.swift
//  Atlas
//

import Foundation

/// The other version of a field that both the person and an assistant
/// edited. The review sheet shows both side by side; one has to be picked
/// before the change can be pushed. Picking it carries its note (the
/// assistant's reason, `PendingChange.groupNote`) and its block with it.
struct ChangeAlternative: Hashable, Codable, Sendable {
    var newValue: String
    var source: ChangeSource
    var requests: [PushRequest]
    var restoreRequests: [PushRequest] = []
    /// Why the assistant proposes it, e.g. "The event now ends on a
    /// Wednesday."; nil when it said nothing.
    var note: String?
    /// Why this version can't be pushed; nil when it can.
    var blockedReason: String?
    /// The assistant's details, how sure and gloss, which go with it when
    /// it's picked; nil when it sent none and in versions saved before.
    var layers: SuggestionLayers?
}
