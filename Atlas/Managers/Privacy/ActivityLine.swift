//
//  ActivityLine.swift
//  Atlas
//

import Foundation

/// One line of Settings → Privacy & Data → Activity: a push, or a call an
/// assistant made, newest first.
struct ActivityLine: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case push
        case assistant
    }

    var id: String
    var date: Date
    var kind: Kind
    var title: String
    var detail: String

    /// Every push and every assistant call, newest first.
    static func lines(pushes: [PushRecord], calls: [MCPLogEntry]) -> [ActivityLine] {
        let pushed = pushes.map { record in
            let failed = record.failedCount
            let detail = failed > 0
                ? String(localized: "\(record.succeededCount) pushed, \(failed) not pushed")
                : String(localized: "\(record.succeededCount) pushed")
            return ActivityLine(
                id: "push-\(record.id)", date: record.date, kind: .push,
                title: "\(record.appName): \(record.title)", detail: detail
            )
        }
        let called = calls.map { entry in
            ActivityLine(
                id: "call-\(entry.id)", date: entry.date, kind: .assistant,
                title: "\(entry.client): \(entry.tool)",
                detail: [entry.outcome.title, entry.target, entry.reason].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " · ")
            )
        }
        return (pushed + called).sorted { $0.date > $1.date }
    }

    /// Export…: the lines as pretty JSON.
    static func exportData(_ lines: [ActivityLine]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(lines)
    }
}
