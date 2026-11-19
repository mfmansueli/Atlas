//
//  AIFilingKind.swift
//  Atlas
//

import Foundation

/// What the Cyberspace Administration of China filed: the large language
/// model, or the algorithm.
enum AIFilingKind: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case largeLanguageModel
    case algorithm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largeLanguageModel: String(localized: "Large language model")
        case .algorithm: String(localized: "Algorithm")
        }
    }

    /// "LLM" or "algorithm", inside a sentence.
    var shortName: String {
        switch self {
        case .largeLanguageModel: String(localized: "LLM")
        case .algorithm: String(localized: "algorithm")
        }
    }
}
