//
//  InAppEventArtworkCheckerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Holding an event's card and details page against Apple's rules: each
/// refusal says how to fix it, and warnings never block.
@Suite("In-App Event artwork checks")
struct InAppEventArtworkCheckerTests {
    private static func image(_ width: Int, _ height: Int, name: String = "card.png", size: Int = 2_000_000) -> InAppEventArtworkFile {
        InAppEventArtworkFile(fileName: name, fileSize: size, isVideo: false, pixelSize: PixelSize(width: width, height: height), colorModel: "RGB")
    }

    private static func video(
        _ width: Int = 1920, _ height: Int = 1080, fps: Double = 30, seconds: Double = 15, codec: String = "avc1",
        audio: [InAppEventArtworkFile.Audio] = []
    ) -> InAppEventArtworkFile {
        InAppEventArtworkFile(
            fileName: "loop.mp4", fileSize: 40_000_000, isVideo: true, pixelSize: PixelSize(width: width, height: height),
            frameRate: fps, seconds: seconds, codec: codec, audio: audio
        )
    }

    private static func refusals(_ file: InAppEventArtworkFile, _ kind: InAppEventMedia.Kind = .card) -> [String] {
        InAppEventArtworkChecker.checks(file, kind: kind, look: nil).filter(\.isRefusal).map(\.text)
    }

    @Test(arguments: [(1920, 1080), (2560, 1440), (3840, 2160)])
    func everyCardSizeApplesRangeTakesPasses(width: Int, height: Int) {
        #expect(Self.refusals(Self.image(width, height)).isEmpty)
        #expect(Self.refusals(Self.image(height, width), .details).isEmpty)
    }

    @Test func aSizeOutsideTheRangeSaysTheRange() {
        #expect(Self.refusals(Self.image(1280, 720)) == ["1280 × 720 is outside Apple's range for the event card: make it at least 1920 × 1080."])
        #expect(Self.refusals(Self.image(5120, 2880)) == ["5120 × 2880 is outside Apple's range for the event card: make it at most 3840 × 2160."])
        #expect(Self.refusals(Self.image(720, 1280), .details)
            == ["720 × 1280 is outside Apple's range for the details page: make it at least 1080 × 1920."])
    }

    @Test func aWrongRatioOrOrientationIsRefused() {
        #expect(Self.refusals(Self.image(2000, 1080))
            == ["2000 × 1080 isn't 16:9. The event card is exactly 16:9, from 1920 × 1080 up to 3840 × 2160."])
        #expect(Self.refusals(Self.image(1080, 1920)) == [
            "1080 × 1920 is portrait, but the event card is 16:9: this looks like the details page (9:16). Send it as that kind, or make a 16:9 one.",
        ])
        #expect(Self.refusals(Self.image(1920, 1080), .details).first?.contains("this looks like the card (16:9)") == true)
    }

    @Test func aFormatAppleDoesntTakeOrAFileOver500MBIsRefused() {
        #expect(Self.refusals(Self.image(1920, 1080, name: "card.heic"))
            == ["“card.heic” is an image Apple takes only as .jpeg, .jpg, or .png: export it as one of those."])
        var webm = Self.video()
        webm.fileName = "loop.webm"
        #expect(Self.refusals(webm).first?.hasPrefix("“loop.webm” is a video Apple takes only as .m4v, .mov, or .mp4") == true)
        #expect(Self.refusals(Self.image(1920, 1080, size: 500_000_001)).first?.contains("Apple takes 500 MB at most") == true)
    }

    @Test(arguments: [(24.0, false), (25.0, false), (29.97, true), (30.0, true), (59.94, true), (60.0, true), (120.0, false)])
    func aVideoRunsAt30Or60FramesASecond(fps: Double, passes: Bool) {
        let refusals = Self.refusals(Self.video(fps: fps))
        #expect(refusals.isEmpty == passes)
        if !passes { #expect(refusals.first?.contains("Apple takes 30 or 60 fps") == true) }
    }

    @Test func audioIsStereoAACOrPCMAt44Or48Kilohertz() {
        let stereo = InAppEventArtworkFile.Audio(format: "aac", channels: 2, sampleRate: 48000)
        #expect(Self.refusals(Self.video(audio: [stereo])).isEmpty)
        #expect(Self.refusals(Self.video(audio: [])).isEmpty)
        let mono = InAppEventArtworkFile.Audio(format: "aac", channels: 1, sampleRate: 44100)
        #expect(Self.refusals(Self.video(audio: [mono])).first?.contains("Apple takes stereo only") == true)
        let pcm = InAppEventArtworkFile.Audio(format: "lpcm", channels: 2, sampleRate: 48000)
        #expect(Self.refusals(Self.video(audio: [pcm])) == ["The audio is “lpcm”; the event card takes AAC, or no audio."])
        #expect(Self.refusals(Self.video(1080, 1920, audio: [pcm]), .details).isEmpty)
        let low = InAppEventArtworkFile.Audio(format: "aac", channels: 2, sampleRate: 22050)
        #expect(Self.refusals(Self.video(audio: [low])) == ["The audio is 22.05 kHz; Apple takes 44.1 or 48 kHz."])
    }

    @Test func whatAppleAdvisesAgainstWarnsWithoutRefusing() {
        var file = Self.image(1920, 1080)
        file.hasAlpha = true
        file.colorModel = "CMYK"
        let look = InAppEventArtworkLook(text: ["GRATITUDE", "WEEK"], lowerBusyness: 0.3)
        let checks = InAppEventArtworkChecker.checks(file, kind: .card, look: look)
        #expect(InAppEventArtworkChecker.canQueue(checks))
        #expect(checks.allSatisfy { $0.severity == .warning })
        let texts = checks.map(\.text)
        #expect(texts.contains { $0.hasPrefix("The image has an alpha channel.") })
        #expect(texts.contains("The image is CMYK, not RGB: export it as sRGB or Display P3."))
        #expect(texts.contains { $0.hasPrefix("The art has text in it (“GRATITUDE”, “WEEK”).") })
        #expect(texts.contains { $0.hasPrefix("The lower part is busy (30% sharp edges)") })

        let video = InAppEventArtworkChecker.checks(Self.video(seconds: 45, codec: "vp09"), kind: .card, look: nil)
        #expect(InAppEventArtworkChecker.canQueue(video))
        #expect(video.map(\.text).contains { $0.hasPrefix("The video is encoded as “vp09”.") })
        #expect(video.map(\.text).contains { $0.hasPrefix("The video is 45 seconds.") })
    }

    @Test func refusalsComeBeforeWarnings() {
        var file = Self.image(1280, 720)
        file.hasAlpha = true
        let checks = InAppEventArtworkChecker.checks(file, kind: .card, look: InAppEventArtworkLook(text: ["Hi"]))
        #expect(checks.map(\.severity) == [.refusal, .warning, .warning])
        #expect(!InAppEventArtworkChecker.canQueue(checks))
    }

    @Test(arguments: [(0.0, 30.0, "00:00:00:00"), (1.5, 30.0, "00:00:01:15"), (2.0, 60.0, "00:00:02:00"), (75.25, 60.0, "00:01:15:15")])
    func aPosterFrameIsATimeCode(seconds: Double, fps: Double, code: String) {
        #expect(InAppEventArtworkRules.timeCode(seconds: seconds, frameRate: fps) == code)
    }
}
