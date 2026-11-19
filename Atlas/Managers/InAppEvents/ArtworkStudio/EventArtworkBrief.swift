//
//  EventArtworkBrief.swift
//  Atlas
//

import Foundation

/// The words around a run: the brief written from the event's texts, how
/// long it takes, and what it makes, as the Brief and Making steps say
/// them.
enum EventArtworkBrief {
    /// The brief to start from: the event's name and descriptions, and the
    /// one rule every concept keeps.
    static func written(for event: InAppEvent) -> String {
        let texts = event.primaryLocalization
        let written = texts?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = written.isEmpty ? event.referenceName : written
        var parts = [String(localized: "Art for “\(name)”.")]
        for text in [texts?.shortDescription, texts?.longDescription].compactMap(\.self) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !parts.contains(trimmed) else { continue }
            parts.append(".!?。".contains(trimmed.last ?? " ") ? trimmed : trimmed + ".")
        }
        parts.append(String(localized: "In the app’s colors, with nothing busy in the lower third, where the App Store writes the event’s name."))
        return parts.joined(separator: " ")
    }

    /// About how many minutes the whole run takes. Each concept is drawn,
    /// rendered and looked at before it's sent: on Alba (2026-11-18) a
    /// template run took 8½ minutes, about 3 a concept.
    static func minutes(style: EventArtworkStyle, wordsInArt: Bool, makesMotion: Bool) -> Int {
        let base = style == .newLook ? 10 : 9
        return base + (makesMotion ? (style == .newLook ? 4 : 2) : 0) + (wordsInArt ? 3 : 0)
    }

    /// Make Them Move: about three minutes a concept (two pages animated,
    /// checked, then each made into a 20-second video).
    static func motionMinutes(concepts: Int) -> Int {
        max(1, 3 * concepts)
    }

    /// Minutes left once `ready` of the concepts are in.
    static func minutesLeft(style: EventArtworkStyle, wordsInArt: Bool, makesMotion: Bool, ready: Int) -> Int {
        max(1, minutes(style: style, wordsInArt: wordsInArt, makesMotion: makesMotion) - 3 * ready)
    }

    /// The Brief step's footer: "3 concepts, each a matching pair · about
    /// 6 min · nothing reaches the App Store until you push".
    static func summary(style: EventArtworkStyle, wordsInArt: Bool, makesMotion: Bool, appName: String, count: Int = 3) -> String {
        let what = switch style {
        case .newLook: String(localized: "\(count) concepts, each a matching pair")
        case .template: String(localized: "\(count) concepts from Atlas’s event layouts, in \(appName)’s colors")
        case .extendCard: String(localized: "\(count) versions of the details image, extended from your card")
        }
        let time = minutes(style: style, wordsInArt: wordsInArt, makesMotion: makesMotion)
        return String(localized: "\(what) · about \(time) min · nothing reaches the App Store until you push")
    }

    /// What you'll get, under the two image sizes.
    static func result(style: EventArtworkStyle, wordsInArt: Bool, makesMotion: Bool, languages: Int) -> String {
        guard style != .extendCard else { return String(localized: "Your event card stays as it is. Only the details image is new.") }
        let pairs = wordsInArt
            ? String(localized: "One pair for each of the \(languages) languages")
            : String(localized: "One pair for all \(languages) languages")
        return pairs + (makesMotion ? String(localized: ", plus a moving version of each.") : ".")
    }

    /// The line under Words in the art.
    static func wordsDetail(isOn: Bool, languages: Int) -> String {
        isOn
            ? String(localized: "On: the event name is drawn into the art, so Atlas makes a pair for each of the \(languages) languages.")
            : String(localized: "Off: the App Store writes the name and description over the image in each language, so one pair works everywhere.")
    }

    /// The Making step's line: "1 of 3 concepts ready · about 4 min left".
    static func progress(ready: Int, of count: Int, minutesLeft: Int) -> String {
        String(localized: "\(ready) of \(count) concepts ready · about \(minutesLeft) min left")
    }
}
