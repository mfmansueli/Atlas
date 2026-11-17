//
//  AppStoreConnectLinkedPage.swift
//  Atlas
//

import Foundation

/// One page of a collection whose resources carry their relationships'
/// linkage, e.g. review submissions with the version each is for.
struct AppStoreConnectLinkedPage<Attributes: Decodable & Sendable>: Decodable, Sendable {
    var data: [AppInformationResourceDocument<Attributes>.Resource]
    var links: AppStoreConnectPageLinks?
}
