//
//  NominationIncludedAttributes.swift
//  Atlas
//

import Foundation

/// What a nominations page's `included` resources say that Atlas shows:
/// an app's name (`apps`), an event's reference name (`appEvents`), who
/// created or submitted it (`actors`, API 4.6.1: `actorType` `USER`,
/// `API_KEY`, `XCODE_CLOUD` or `APPLE`). Territories come too, with only
/// their `currency`, which Atlas doesn't read.
struct NominationIncludedAttributes: Decodable, Sendable {
    var name: String?
    var referenceName: String?
    var actorType: String?
    var userFirstName: String?
    var userLastName: String?
    var apiKeyId: String?
}
