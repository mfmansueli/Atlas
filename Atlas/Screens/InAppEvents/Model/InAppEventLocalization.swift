//
//  InAppEventLocalization.swift
//  Atlas
//

import Foundation

/// One language of an In-App Event: its name (30), short description (50)
/// and long description (120), and the images and video uploaded for it.
struct InAppEventLocalization: Hashable, Sendable {
    /// The `appEventLocalizations` id.
    var id: String
    /// An App Store locale code, e.g. `de-DE`.
    var locale: String
    var name = ""
    var shortDescription = ""
    var longDescription = ""
    var media: [InAppEventMedia] = []

    func text(_ field: InAppEventField) -> String {
        switch field {
        case .name: name
        case .shortDescription: shortDescription
        case .longDescription: longDescription
        }
    }

    /// Every text is written.
    var isComplete: Bool {
        InAppEventField.allCases.allSatisfy { !text($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
