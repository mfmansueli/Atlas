//
//  HLSPlaylist.swift
//  Atlas
//

import Foundation

/// An HTTP Live Streaming playlist, as far as `RemoteVideoCache` reads one
/// (App Store Connect streams an In-App Event's clip this way): the
/// versions of a stream at their sizes, or one version's pieces of movie
/// in order.
enum HLSPlaylist: Equatable, Sendable {
    /// One version of the stream: its own playlist, its size when the
    /// playlist says, and its peak bit rate.
    struct Variant: Equatable, Sendable {
        let url: URL
        var width: Int?
        var height: Int?
        var bandwidth = 0

        /// The longer of its two sides; 0 when the playlist doesn't say.
        var longSide: Int { max(width ?? 0, height ?? 0) }
    }

    /// A piece of the movie: a whole file, or a byte range of one.
    struct Part: Equatable, Sendable {
        let url: URL
        var range: Range<Int>?
    }

    /// A multivariant playlist: the versions (`#EXT-X-STREAM-INF`),
    /// trick-play versions left out.
    case multivariant([Variant])
    /// One version: `map` is the movie's header (a fragmented MP4's
    /// initialization section; nil for MPEG-TS pieces), then its pieces.
    case media(map: Part?, segments: [Part], isEncrypted: Bool)

    /// Nil when `text` isn't a playlist. Addresses are read against `base`.
    static func parse(_ text: String, base: URL) -> HLSPlaylist? {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.first(where: { !$0.isEmpty }) == "#EXTM3U" else { return nil }
        if lines.contains(where: { $0.hasPrefix("#EXT-X-STREAM-INF:") }) {
            return .multivariant(variants(in: lines, base: base))
        }
        return media(in: lines, base: base)
    }

    /// The version to keep: the largest no longer than `maxSide` on its
    /// longest side, the lightest of equal ones; when all are larger, the
    /// smallest.
    static func variant(in variants: [Variant], maxSide: Int) -> Variant? {
        let fitting = variants.filter { $0.longSide <= maxSide }
        if let best = fitting.max(by: { ($0.longSide, -$0.bandwidth) < ($1.longSide, -$1.bandwidth) }) { return best }
        return variants.min { ($0.longSide, $0.bandwidth) < ($1.longSide, $1.bandwidth) }
    }

    // MARK: - Reading

    private static func variants(in lines: [String], base: URL) -> [Variant] {
        var found: [Variant] = []
        var pending: [String: String]?
        for line in lines where !line.isEmpty {
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                pending = attributes(String(line.dropFirst("#EXT-X-STREAM-INF:".count)))
            } else if line.hasPrefix("#") {
                continue
            } else if let info = pending {
                pending = nil
                guard let url = URL(string: line, relativeTo: base)?.absoluteURL else { continue }
                let size = info["RESOLUTION"]?.lowercased().split(separator: "x").compactMap { Int($0) } ?? []
                found.append(Variant(
                    url: url, width: size.count == 2 ? size[0] : nil, height: size.count == 2 ? size[1] : nil,
                    bandwidth: info["BANDWIDTH"].flatMap { Int($0) } ?? info["AVERAGE-BANDWIDTH"].flatMap { Int($0) } ?? 0
                ))
            }
        }
        return found
    }

    private static func media(in lines: [String], base: URL) -> HLSPlaylist {
        var map: Part?
        var segments: [Part] = []
        var isEncrypted = false
        var pendingRange: (length: Int, offset: Int?)?
        /// Where the last range of each file ended, for a range that
        /// gives no offset.
        var ends: [URL: Int] = [:]

        func part(_ uri: String, range: (length: Int, offset: Int?)?) -> Part? {
            guard let url = URL(string: uri, relativeTo: base)?.absoluteURL else { return nil }
            guard let range else { return Part(url: url) }
            let start = range.offset ?? ends[url] ?? 0
            ends[url] = start + range.length
            return Part(url: url, range: start..<(start + range.length))
        }

        for line in lines where !line.isEmpty {
            if line.hasPrefix("#EXT-X-MAP:") {
                let info = attributes(String(line.dropFirst("#EXT-X-MAP:".count)))
                if let uri = info["URI"] { map = part(uri, range: info["BYTERANGE"].flatMap(byteRange)) }
            } else if line.hasPrefix("#EXT-X-BYTERANGE:") {
                pendingRange = byteRange(String(line.dropFirst("#EXT-X-BYTERANGE:".count)))
            } else if line.hasPrefix("#EXT-X-KEY:") {
                let method = attributes(String(line.dropFirst("#EXT-X-KEY:".count)))["METHOD"] ?? "NONE"
                if method != "NONE" { isEncrypted = true }
            } else if line.hasPrefix("#") {
                continue
            } else {
                if let segment = part(line, range: pendingRange) { segments.append(segment) }
                pendingRange = nil
            }
        }
        return .media(map: map, segments: segments, isEncrypted: isEncrypted)
    }

    /// `KEY=VALUE,KEY="VALUE, WITH COMMAS"`.
    static func attributes(_ text: String) -> [String: String] {
        var found: [String: String] = [:]
        var key = "", value = ""
        var isReadingValue = false, isQuoted = false
        func finish() {
            let name = key.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { found[name] = value }
            key = ""
            value = ""
            isReadingValue = false
        }
        for character in text {
            if isQuoted {
                if character == "\"" { isQuoted = false } else { value.append(character) }
            } else if character == "\"" {
                isQuoted = true
            } else if character == "," {
                finish()
            } else if character == "=", !isReadingValue {
                isReadingValue = true
            } else if isReadingValue {
                value.append(character)
            } else {
                key.append(character)
            }
        }
        finish()
        return found
    }

    /// "375739@884" or "375739".
    static func byteRange(_ text: String) -> (length: Int, offset: Int?)? {
        let pieces = text.split(separator: "@").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = pieces.first, let length = Int(first), length > 0 else { return nil }
        guard pieces.count > 1 else { return (length, nil) }
        guard let offset = Int(pieces[1]), offset >= 0 else { return nil }
        return (length, offset)
    }
}
