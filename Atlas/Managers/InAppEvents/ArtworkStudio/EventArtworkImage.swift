//
//  EventArtworkImage.swift
//  Atlas
//

import Foundation

/// One rendered file of a concept: its card or details image, for every
/// language (`locale` nil) or for one when the art has words, a still or
/// the moving version.
struct EventArtworkImage: Codable, Hashable, Sendable {
    var kind: InAppEventMedia.Kind
    /// Nil when the same file goes into every language.
    var locale: String?
    var fileID: String
    /// The file on this Mac.
    var path: String
    var isVideo = false
}
