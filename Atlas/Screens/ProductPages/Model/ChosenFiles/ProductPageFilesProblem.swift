//
//  ProductPageFilesProblem.swift
//  Atlas
//

import Foundation

/// Why Choose Files… didn't add the screenshots: the alert's title and one
/// line per problem.
struct ProductPageFilesProblem: Identifiable, Hashable, Sendable {
    var id = UUID()
    let pageName: String
    let problems: [String]

    var title: String {
        String(localized: "These screenshots can’t go to “\(pageName)”")
    }

    var message: String {
        problems.joined(separator: "\n")
    }
}
