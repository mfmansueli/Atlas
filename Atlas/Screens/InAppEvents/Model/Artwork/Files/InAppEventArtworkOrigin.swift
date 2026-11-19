//
//  InAppEventArtworkOrigin.swift
//  Atlas
//

import Foundation

/// Where an event card or details page file came from: a page
/// render_event_artwork rendered, an image sent to it in base64, a file
/// sent to the upload link, or one the person chose in Atlas; and, once a
/// Make the Artwork concept carries it, that concept.
struct InAppEventArtworkOrigin: Codable, Hashable, Sendable {
    enum Source: String, Codable, Hashable, Sendable {
        /// An HTML page render_event_artwork (or a concept) rendered.
        case page
        /// An image render_event_artwork got in base64.
        case image
        /// A file sent to get_in_app_events' artworkUpload link.
        case upload
        /// A file the person chose with Choose Files….
        case chosenFile
    }

    var source: Source
    /// The rendered page's file name, the upload's `?name=`, the base64
    /// image's or the chosen file's name.
    var name: String?
    /// The Make the Artwork concept the file belongs to.
    var conceptID: String?
    /// That concept's name, e.g. "Snowfall Path".
    var conceptTitle: String?

    /// `{from, page | name, conceptId, title}` for the MCP tools: `from` is
    /// makeTheArtwork for a concept's file, else render_event_artwork,
    /// imageBase64, upload or chooseFiles.
    var json: JSONValue {
        var object: [String: JSONValue] = [:]
        object["from"] = switch source {
        case .page: "render_event_artwork"
        case .image: "imageBase64"
        case .upload: "upload"
        case .chosenFile: "chooseFiles"
        }
        if let name { object[source == .page ? "page" : "name"] = .string(name) }
        if let conceptID {
            object["from"] = "makeTheArtwork"
            object["conceptId"] = .string(conceptID)
            if let conceptTitle { object["title"] = .string(conceptTitle) }
        }
        return .object(object)
    }
}
