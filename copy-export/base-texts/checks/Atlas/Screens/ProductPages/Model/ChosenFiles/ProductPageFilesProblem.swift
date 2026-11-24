//
//  ProductPageFilesProblem.swift
//  Atlas
//

import Foundation

/// Why Choose Files… (or Choose App Previews…) didn't add them: the alert's title and one
/// line per problem.
struct ProductPageFilesProblem: Identifiable, Hashable, Sendable {
    var id = UUID()
    let pageName: String
    let problems: [String]
    var media: ProductPageMedia = .screenshots

    var title: String {
        switch media {
        case .screenshots: String(localized: "These screenshots can’t go to “\(pageName)”")
        case .appPreviews: String(localized: "These App Previews can’t go to “\(pageName)”")
        }
    }

    var message: String {
        problems.joined(separator: "\n")
    }
}
