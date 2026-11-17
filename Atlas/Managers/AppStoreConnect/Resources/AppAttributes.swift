//
//  AppAttributes.swift
//  Atlas
//

import Foundation

/// The `apps` resource attributes Atlas asks for (`fields[apps]`).
struct AppAttributes: Decodable, Sendable {
    var name: String
    var bundleId: String
    var sku: String?
    var primaryLocale: String?
}
