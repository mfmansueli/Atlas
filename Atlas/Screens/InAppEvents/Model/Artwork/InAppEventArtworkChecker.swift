//
//  InAppEventArtworkChecker.swift
//  Atlas
//

import Foundation

/// Holds an event card or details page against Apple's rules
/// (`InAppEventArtworkRules`). Refusals say how to fix what Apple won't
/// take; warnings are what Apple advises against or doesn't state: words
/// in the art, a busy lower part where the name goes, transparency, a
/// color model other than RGB, a codec Apple doesn't name.
enum InAppEventArtworkChecker {
    /// Every check of `file` as the event's `kind`, refusals first.
    static func checks(_ file: InAppEventArtworkFile, kind: InAppEventMedia.Kind, look: InAppEventArtworkLook?) -> [InAppEventArtworkCheck] {
        var checks = formatChecks(file) + sizeChecks(file, kind: kind)
        if file.isVideo { checks += videoChecks(file, kind: kind) }
        if let look { checks += lookChecks(look) }
        return checks.filter(\.isRefusal) + checks.filter { !$0.isRefusal }
    }

    static func canQueue(_ checks: [InAppEventArtworkCheck]) -> Bool {
        !checks.contains(where: \.isRefusal)
    }

    // MARK: - Apple's rules

    private static func formatChecks(_ file: InAppEventArtworkFile) -> [InAppEventArtworkCheck] {
        var checks: [InAppEventArtworkCheck] = []
        let allowed = file.isVideo ? InAppEventArtworkRules.videoExtensions : InAppEventArtworkRules.imageExtensions
        if !allowed.contains(file.fileExtension) {
            let list = file.isVideo ? ".m4v, .mov, or .mp4" : ".jpeg, .jpg, or .png"
            checks.append(.refusal(String(localized: """
            “\(file.fileName)” is \(file.isVideo ? "a video" : "an image") Apple takes only as \(list): export it as one of those.
            """)))
        }
        if file.fileSize > InAppEventArtworkRules.maximumFileSize {
            let size = Int64(file.fileSize).formatted(.byteCount(style: .file))
            checks.append(.refusal(String(localized: "The file is \(size); Apple takes 500 MB at most. Compress it or shorten the video.")))
        }
        if !file.isVideo {
            if file.hasAlpha {
                checks.append(.warning(String(localized: """
                The image has an alpha channel. Apple doesn't say event media may be transparent: flatten it onto its \
                background before proposing it.
                """)))
            }
            if let model = file.colorModel, model != "RGB" {
                checks.append(.warning(String(localized: "The image is \(model), not RGB: export it as sRGB or Display P3.")))
            }
        }
        return checks
    }

    private static func sizeChecks(_ file: InAppEventArtworkFile, kind: InAppEventMedia.Kind) -> [InAppEventArtworkCheck] {
        let size = file.pixelSize
        let low = InAppEventArtworkRules.minimumSize(for: kind)
        let high = InAppEventArtworkRules.maximumSize(for: kind)
        let ratio = kind.ratioTitle
        if size.isLandscape != low.isLandscape, size.width != size.height {
            let other = kind == .card ? String(localized: "the details page (9:16)") : String(localized: "the card (16:9)")
            return [.refusal(String(localized: """
            \(size.title) is \(size.isLandscape ? "landscape" : "portrait"), but the \(kind.name) is \(ratio): \
            this looks like \(other). Send it as that kind, or make a \(ratio) one.
            """))]
        }
        guard !InAppEventArtworkRules.fits(size, kind) else { return [] }
        if !InAppEventArtworkRules.hasRatio(size, of: kind) {
            return [.refusal(String(localized: """
            \(size.title) isn't \(ratio). The \(kind.name) is exactly \(ratio), from \(low.title) up to \(high.title).
            """))]
        }
        let fix = size.width < low.width ? String(localized: "at least \(low.title)") : String(localized: "at most \(high.title)")
        return [.refusal(String(localized: "\(size.title) is outside Apple's range for the \(kind.name): make it \(fix)."))]
    }

    private static func videoChecks(_ file: InAppEventArtworkFile, kind: InAppEventMedia.Kind) -> [InAppEventArtworkCheck] {
        var checks: [InAppEventArtworkCheck] = []
        if let rate = file.frameRate, !InAppEventArtworkRules.frameRates.contains(where: { abs($0 - rate) < 0.5 }) {
            checks.append(.refusal(String(localized: "The video runs at \(Self.rate(rate)) fps; Apple takes 30 or 60 fps. Export it at one of those.")))
        }
        if let codec = file.codec, !InAppEventArtworkRules.knownVideoCodecs.contains(codec) {
            checks.append(.warning(String(localized: """
            The video is encoded as “\(codec)”. Apple doesn't name codecs for event videos; H.264, HEVC or ProRes 422 \
            HQ are the safe choice.
            """)))
        }
        if let seconds = file.seconds, seconds > 30 {
            checks.append(.warning(String(localized: """
            The video is \(Int(seconds.rounded())) seconds. It plays on repeat; Apple states no length for event videos, \
            but App Previews stop at 30 seconds, so a shorter seamless loop is safer.
            """)))
        }
        for audio in file.audio {
            if audio.channels != 2 {
                checks.append(.refusal(String(localized: """
                The audio has \(audio.channels) channel(s); Apple takes stereo only. Mix it to stereo or leave the audio out.
                """)))
            }
            let formats = kind == .card ? ["aac"] : ["aac", "lpcm"]
            if !formats.contains(audio.format) {
                let allowed = kind == .card ? String(localized: "AAC") : String(localized: "AAC or PCM")
                checks.append(.refusal(String(localized: "The audio is “\(audio.format)”; the \(kind.name) takes \(allowed), or no audio.")))
            }
            if !InAppEventArtworkRules.audioSampleRates.contains(where: { abs($0 - audio.sampleRate) < 1 }) {
                checks.append(.refusal(String(localized: "The audio is \(Self.rate(audio.sampleRate / 1000)) kHz; Apple takes 44.1 or 48 kHz.")))
            }
        }
        return checks
    }

    // MARK: - What Apple advises against

    private static func lookChecks(_ look: InAppEventArtworkLook) -> [InAppEventArtworkCheck] {
        var checks: [InAppEventArtworkCheck] = []
        if !look.text.isEmpty {
            let words = look.text.prefix(4).map { "“\($0)”" }.joined(separator: ", ")
            checks.append(.warning(String(localized: """
            The art has text in it (\(words)). Apple asks for none, especially the event's or the app's name: it lays the \
            badge, name and description over it in each language.
            """)))
        }
        if look.isLowerPartBusy {
            checks.append(.warning(String(localized: """
            The lower part is busy (\(Int((look.lowerBusyness * 100).rounded()))% sharp edges): Apple lays the event's name \
            there, so keep it calm or darker for the white text to read.
            """)))
        }
        return checks
    }

    private static func rate(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}
