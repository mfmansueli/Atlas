//
//  BackgroundJob.swift
//  Atlas
//

import Foundation

/// One line under "Running now" in the menu bar's menu: "Pushing to App
/// Store Connect", its bar, and "14 of 23 changes · Lumen Journal · about
/// 1 min left".
struct BackgroundJob: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case push
        case screenshotPush
        case autopilot
        case suggestEverything
        /// Claude drawing an In-App Event's artwork.
        case eventArtwork
        case check
    }

    var id: String
    var kind: Kind
    var title: String
    /// 0…1; nil draws no bar (a check doesn't know how far it is).
    var fraction: Double?
    var detail: String
}
