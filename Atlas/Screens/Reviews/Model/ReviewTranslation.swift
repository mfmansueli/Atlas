//
//  ReviewTranslation.swift
//  Atlas
//

import Foundation

/// A review's title and text in the app's language.
struct ReviewTranslation: Hashable, Codable, Sendable {
    var title: String
    var body: String
}
