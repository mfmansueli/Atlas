//
//  NominationIncludedAttributes.swift
//  Atlas
//

import Foundation

/// What a nominations page's `included` resources say that Atlas shows:
/// an app's name, an event's reference name, who created or submitted it.
struct NominationIncludedAttributes: Decodable, Sendable {
    var name: String?
    var referenceName: String?
    var actorType: String?
    var userFirstName: String?
    var userLastName: String?
    var apiKeyId: String?
}
