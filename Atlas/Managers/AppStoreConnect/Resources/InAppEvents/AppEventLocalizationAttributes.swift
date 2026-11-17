//
//  AppEventLocalizationAttributes.swift
//  Atlas
//

import Foundation

/// An `appEventLocalizations` resource: one language's texts of an event.
struct AppEventLocalizationAttributes: Decodable, Sendable {
    var locale: String?
    var name: String?
    var shortDescription: String?
    var longDescription: String?
}
