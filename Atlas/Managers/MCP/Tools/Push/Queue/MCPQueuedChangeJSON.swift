//
//  MCPQueuedChangeJSON.swift
//  Atlas
//

import Foundation

/// One change waiting in Review & Push as `get_queued_changes` returns
/// it: what changes, from what to what, who proposed it and whether a push
/// would send it.
enum MCPQueuedChangeJSON {
    /// `ready` (a push sends it), `blocked` (with `reason`),
    /// `needsDecision` (a conflict or two versions the person picks from)
    /// or `awaitingAcceptance` (an assistant's proposal the person keeps
    /// first).
    static func status(_ change: PendingChange) -> String {
        if change.awaitingAcceptance != nil { return "awaitingAcceptance" }
        if change.needsDecision { return "needsDecision" }
        if change.blockedReason != nil { return "blocked" }
        return "ready"
    }

    static func json(_ change: PendingChange, source: ChangeSource) -> JSONValue {
        var object: [String: JSONValue] = [
            "changeId": .string(change.id),
            "section": .string(change.section.rawValue),
            "group": .string(change.group),
            "title": .string(change.title),
            "to": .string(change.newValue),
            "by": .string(change.source.title),
            "mine": .bool(change.source == source),
            "status": .string(status(change)),
            "createdAt": .string(change.createdAt.formatted(.iso8601)),
        ]
        if !change.oldValue.isEmpty { object["from"] = .string(change.oldValue) }
        if let creation = change.creation {
            object["row"] = .string(creation.title)
            if !creation.detail.isEmpty { object["detail"] = .string(creation.detail) }
        }
        if let note = change.groupNote, !note.isEmpty { object["note"] = .string(note) }
        if let reason = change.blockingMessage { object["reason"] = .string(reason) }
        if let alternative = change.alternative {
            object["alternative"] = [
                "to": .string(alternative.newValue),
                "by": .string(alternative.source.title),
                "mine": .bool(alternative.source == source),
            ]
        }
        if let parent = change.dependsOn { object["dependsOn"] = .string(parent) }
        if let option = change.option { object["option"] = ["title": .string(option.title), "on": .bool(option.isOn)] }
        return .object(object)
    }
}
