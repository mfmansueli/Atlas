//
//  LiveAppPreview.swift
//  Atlas
//

import Foundation

/// One App Preview live in a set, as App Store Connect lists it: what the
/// Screenshots page names when it's replaced, moved or deleted by hand.
struct LiveAppPreview: Codable, Hashable, Sendable, Identifiable {
    var id: String
    /// "Lumen-de.mov"; empty when App Store Connect doesn't say.
    var fileName: String
    /// "00:00:05:00".
    var posterFrameTimeCode: String?
}
