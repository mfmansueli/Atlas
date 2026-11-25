//
//  HLSPlaylistTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// App Store Connect streams an event's clip as HLS: Atlas reads the
/// versions, keeps the largest that fits, and joins its pieces into one
/// movie.
@Suite("HLS playlist")
struct HLSPlaylistTests {
    private let base = URL(string: "https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/cd/clip/P1_default.m3u8")!

    private let multivariant = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-INDEPENDENT-SEGMENTS
    #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-stereo-64",NAME="English",URI="audio_en.m3u8"
    #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=61803,RESOLUTION=640x360,URI="iframes_640x360.m3u8"
    #EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=427735,BANDWIDTH=561836,CODECS="avc1.64001e,mp4a.40.2",RESOLUTION=640x360
    video_640x360.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=3275315,CODECS="avc1.640028,mp4a.40.2",RESOLUTION=1920x1080
    https://apptrailers.itunes.apple.com/other/video_1920x1080_high.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=2440692,CODECS="avc1.640028,mp4a.40.2",RESOLUTION=1920x1080
    video_1920x1080.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=9000000,RESOLUTION=3840x2160
    video_3840x2160.m3u8
    """

    @Test func theMultivariantPlaylistListsEachVersionWithItsSizeButNotTrickPlay() throws {
        guard case let .multivariant(variants) = try #require(HLSPlaylist.parse(multivariant, base: base)) else {
            Issue.record("Not read as a multivariant playlist")
            return
        }
        #expect(variants.count == 4)
        #expect(variants[0].url.absoluteString == "https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/cd/clip/video_640x360.m3u8")
        #expect(variants[0].width == 640)
        #expect(variants[0].height == 360)
        #expect(variants[0].bandwidth == 561_836)
        #expect(variants[1].url.absoluteString == "https://apptrailers.itunes.apple.com/other/video_1920x1080_high.m3u8")
    }

    @Test func theLargestVersionThatFitsIsKeptTheLightestOfEqualOnes() throws {
        guard case let .multivariant(variants) = try #require(HLSPlaylist.parse(multivariant, base: base)) else {
            Issue.record("Not read as a multivariant playlist")
            return
        }
        #expect(HLSPlaylist.variant(in: variants, maxSide: 1920)?.url.lastPathComponent == "video_1920x1080.m3u8")
        #expect(HLSPlaylist.variant(in: variants, maxSide: 1000)?.url.lastPathComponent == "video_640x360.m3u8")
        // All larger: the smallest.
        #expect(HLSPlaylist.variant(in: variants, maxSide: 100)?.url.lastPathComponent == "video_640x360.m3u8")
        // A details page's portrait clip fits by its longer side.
        let portrait = HLSPlaylist.Variant(url: base, width: 1080, height: 1920, bandwidth: 1)
        #expect(HLSPlaylist.variant(in: [portrait], maxSide: 1920) == portrait)
        #expect(HLSPlaylist.variant(in: [], maxSide: 1920) == nil)
    }

    @Test func aVersionsPiecesAreByteRangesOfOneFile() throws {
        let text = """
        #EXTM3U
        #EXT-X-TARGETDURATION:6
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-MAP:URI="video-.mp4",BYTERANGE="884@0"
        #EXTINF:6.00000,
        #EXT-X-BYTERANGE:375739@884
        video-.mp4
        #EXTINF:6.00000,
        #EXT-X-BYTERANGE:1000
        video-.mp4
        #EXT-X-ENDLIST
        """
        let movie = try #require(URL(string: "https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/cd/clip/video-.mp4"))
        let playlist = try #require(HLSPlaylist.parse(text, base: base))
        #expect(playlist == .media(
            map: HLSPlaylist.Part(url: movie, range: 0..<884),
            segments: [
                HLSPlaylist.Part(url: movie, range: 884..<376_623),
                // No offset: it follows the one before.
                HLSPlaylist.Part(url: movie, range: 376_623..<377_623),
            ],
            isEncrypted: false
        ))
    }

    @Test func anEncryptedStreamSaysSo() throws {
        let text = """
        #EXTM3U
        #EXT-X-KEY:METHOD=AES-128,URI="key.bin"
        #EXTINF:6,
        a.ts
        """
        guard case let .media(map, segments, isEncrypted) = try #require(HLSPlaylist.parse(text, base: base)) else {
            Issue.record("Not read as a media playlist")
            return
        }
        #expect(map == nil)
        #expect(segments.count == 1)
        #expect(isEncrypted)
    }

    @Test func notAPlaylist() {
        #expect(HLSPlaylist.parse("<html>Not Found</html>", base: base) == nil)
        #expect(HLSPlaylist.parse("", base: base) == nil)
    }

    @Test func attributesKeepCommasInQuotes() {
        let attributes = HLSPlaylist.attributes(#"BANDWIDTH=561836,CODECS="avc1.64001e,mp4a.40.2",RESOLUTION=640x360"#)
        #expect(attributes == ["BANDWIDTH": "561836", "CODECS": "avc1.64001e,mp4a.40.2", "RESOLUTION": "640x360"])
    }

    @Test func byteRanges() {
        #expect(HLSPlaylist.byteRange("375739@884")?.length == 375_739)
        #expect(HLSPlaylist.byteRange("375739@884")?.offset == 884)
        #expect(HLSPlaylist.byteRange("10")?.offset == nil)
        #expect(HLSPlaylist.byteRange("0@0") == nil)
        #expect(HLSPlaylist.byteRange("x") == nil)
    }
}
