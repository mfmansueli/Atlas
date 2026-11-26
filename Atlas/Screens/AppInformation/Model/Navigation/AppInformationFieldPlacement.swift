//
//  AppInformationFieldPlacement.swift
//  Atlas
//

import Foundation

/// The line under a field that says where it shows (board 88). The fields
/// take the page's whole width, with no "On the App Store" preview beside
/// them, so each one says it itself.
enum AppInformationFieldPlacement {
    static var informationSection: String {
        String(localized: "In the Information section of the page", comment: "kind:caption · where an App Information field shows")
    }

    static func primaryCategory(appName: String) -> String {
        String(localized: "Where \(appName) is listed and ranked", comment: "kind:caption · where the primary category shows")
    }

    static func secondaryCategory(appName: String) -> String {
        String(localized: "A second place people find \(appName) when they browse", comment: "kind:caption · where the secondary category shows")
    }

    static func gamesSubcategories(appName: String) -> String {
        String(localized: "Where \(appName) is listed in Games", comment: "kind:caption · where the Games subcategories show")
    }

    /// App Review, Export Compliance, content rights and release.
    static var onlyApple: String {
        String(localized: "Only Apple sees this", comment: "kind:caption · an App Information field that never shows on the App Store")
    }
}
