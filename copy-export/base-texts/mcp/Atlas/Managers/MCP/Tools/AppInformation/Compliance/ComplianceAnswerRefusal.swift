//
//  ComplianceAnswerRefusal.swift
//  Atlas
//

import Foundation

/// Why `propose_compliance_answers` didn't take one answer, in a sentence
/// the assistant can act on.
struct ComplianceAnswerRefusal: Error, Hashable, Sendable {
    let reason: String

    init(_ reason: String) {
        self.reason = reason
    }
}
