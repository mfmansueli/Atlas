//
//  HLSMovieAssembler.swift
//  Atlas
//

import Foundation

/// Joins a streamed clip into one movie file `AVPlayer` plays from this
/// Mac: picks a version of the stream (`HLSPlaylist.variant`), downloads
/// each of its files once and puts its header and pieces together in
/// order, which is a fragmented MP4. Only unencrypted fragmented MP4
/// streams join this way (App Store Connect's do); MPEG-TS pieces or an
/// encrypted stream throw, and the place keeps its poster frame. Its
/// sound, when the version has none of its own, is left out: Atlas plays
/// these clips muted.
enum HLSMovieAssembler {
    /// The movie of the stream whose playlist `data` was read at `url`;
    /// `fetch` answers a file's bytes or throws.
    static func movie(
        playlist data: Data, at url: URL, maxSide: Int, fetch: @Sendable (URL) async throws -> Data
    ) async throws -> Data {
        var playlist = try parse(data, at: url)
        if case let .multivariant(variants) = playlist {
            guard let variant = HLSPlaylist.variant(in: variants, maxSide: maxSide) else { throw URLError(.cannotParseResponse) }
            playlist = try await parse(fetch(variant.url), at: variant.url)
        }
        guard case let .media(map, segments, isEncrypted) = playlist, let map, !segments.isEmpty, !isEncrypted else {
            throw URLError(.cannotDecodeContentData)
        }
        let parts = [map] + segments
        var files: [URL: Data] = [:]
        for part in parts where files[part.url] == nil {
            files[part.url] = try await fetch(part.url)
        }
        var movie = Data()
        for part in parts {
            guard let file = files[part.url] else { throw URLError(.cannotDecodeContentData) }
            guard let range = part.range else {
                movie.append(file)
                continue
            }
            guard range.upperBound <= file.count else { throw URLError(.cannotDecodeContentData) }
            movie.append(file.subdata(in: (file.startIndex + range.lowerBound)..<(file.startIndex + range.upperBound)))
        }
        return movie
    }

    private static func parse(_ data: Data, at url: URL) throws -> HLSPlaylist {
        guard let text = String(data: data, encoding: .utf8), let playlist = HLSPlaylist.parse(text, base: url) else {
            throw URLError(.cannotParseResponse)
        }
        return playlist
    }
}
