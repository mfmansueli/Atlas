//
//  TerritoryAttributes.swift
//  Atlas
//

import Foundation

/// A `territories` resource's one attribute (`GET /v1/territories`): the
/// currency the App Store charges in there, e.g. "BRL". Its ID is the
/// territory's alpha-3 code.
struct TerritoryAttributes: Decodable, Sendable {
    var currency: String?
}
