//
//  EncryptionAnswer.swift
//  Atlas
//

import Foundation

/// The Submit sheet's one encryption question. The answer is written on
/// the build and kept in App Information → Export Compliance, so the next
/// version asks only when something changed.
enum EncryptionAnswer: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// HTTPS and Apple's own APIs: exempt from export documentation.
    case exempt
    case noEncryption
    /// Its own or other encryption: needs export documentation.
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exempt: String(localized: "Standard encryption only")
        case .noEncryption: String(localized: "No encryption")
        case .other: String(localized: "Other encryption")
        }
    }

    var detail: String? {
        switch self {
        case .exempt: String(localized: "HTTPS and Apple’s own APIs. Exempt from export documentation.")
        case .noEncryption: nil
        case .other: String(localized: "Needs export documentation in App Store Connect.")
        }
    }

    /// What the build's `usesNonExemptEncryption` becomes.
    var usesNonExemptEncryption: Bool { self == .other }

    /// As App Information → Export Compliance keeps it.
    var answers: ExportComplianceAnswers {
        var answers: [ExportComplianceQuestion: Bool] = [.usesEncryption: self != .noEncryption]
        if self != .noEncryption { answers[.isExempt] = self == .exempt }
        return ExportComplianceAnswers(answers: answers)
    }

    /// The answer Export Compliance has, when it has one.
    init?(_ answers: ExportComplianceAnswers?) {
        switch (answers?[.usesEncryption], answers?[.isExempt]) {
        case (false?, _): self = .noEncryption
        case (true?, true?): self = .exempt
        case (true?, false?): self = .other
        default: return nil
        }
    }

    /// The answer a build carries: it only says whether documentation is
    /// needed, so "no" reads as standard encryption.
    init?(buildUsesNonExemptEncryption uses: Bool?) {
        guard let uses else { return nil }
        self = uses ? .other : .exempt
    }

    /// The answer `build` carries, else the one kept in App Information →
    /// Export Compliance (`saved`). The build says only whether
    /// documentation is needed; the saved answer says which kind, when the
    /// two agree.
    static func known(saved: EncryptionAnswer?, build: ReleaseBuild?) -> EncryptionAnswer? {
        guard let build, let fromBuild = EncryptionAnswer(buildUsesNonExemptEncryption: build.usesNonExemptEncryption) else { return saved }
        if let saved, saved.usesNonExemptEncryption == fromBuild.usesNonExemptEncryption { return saved }
        return fromBuild
    }
}
