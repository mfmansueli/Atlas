//
//  PrivacyQuestionBaseline.swift
//  Atlas
//

import Foundation

/// What an open question's affected types and the first question were just
/// before the person first answered it. Changing the answer starts again
/// from here, so Yes then No doesn't leave Yes's answers behind.
struct PrivacyQuestionBaseline: Hashable, Codable, Sendable {
    /// The affected types' rows; a type missing here had none.
    var entries: [PrivacyDataType: PrivacyTypeEntry]
    var collects: PrivacyCollectsAnswer?
}
