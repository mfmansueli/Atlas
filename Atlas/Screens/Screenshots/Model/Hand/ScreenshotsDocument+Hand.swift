//
//  ScreenshotsDocument+Hand.swift
//  Atlas
//

import Foundation

// Screenshots changed by hand: one set per language and device, kept in the
// document from the first edit on (`ScreenshotHandSet`).
extension ScreenshotsDocument {
    var hasHandSets: Bool { !(handSets ?? []).isEmpty }

    /// Atlas makes this language's screenshots on this device from the
    /// template: there's a template, the language is in the scope and not
    /// restored, and the template lays the device out.
    func rendersByTemplate(locale: String, displayType: ScreenshotDisplayType) -> Bool {
        template != nil && scope.contains(locale) && !scope.isPinned(locale) && displays.contains(displayType)
    }

    /// What a set is before it's changed by hand: the template's slots, or
    /// the live screenshots in their order (none when the language uses the
    /// primary one's).
    func startingHandBases(locale: String, displayType: ScreenshotDisplayType, live: LiveScreenshots) -> [ScreenshotHandBase] {
        if rendersByTemplate(locale: locale, displayType: displayType) {
            return (0..<slotCount(on: displayType)).map { .template(slot: $0) }
        }
        let shots = live.set(locale: locale, displayType: displayType)?.screenshots ?? []
        return shots.map { .live(id: $0.id, fileName: $0.fileName, checksum: $0.checksum) }
    }

    /// The set as the person left it, or as it starts.
    func handSetOrStart(locale: String, displayType: ScreenshotDisplayType, live: LiveScreenshots) -> ScreenshotHandSet {
        handSet(locale: locale, displayType: displayType)
            ?? .starting(locale: locale, displayType: displayType, bases: startingHandBases(locale: locale, displayType: displayType, live: live))
    }

    /// Saves an edited set, or forgets it when it's back to how it starts.
    mutating func storeHandSet(_ set: ScreenshotHandSet, live: LiveScreenshots) {
        let unchanged = set.isUnchanged(from: startingHandBases(locale: set.locale, displayType: set.displayType, live: live))
        setHandSet(unchanged ? nil : set, locale: set.locale, displayType: set.displayType)
    }

    func handSet(locale: String, displayType: ScreenshotDisplayType) -> ScreenshotHandSet? {
        handSets?.first { $0.locale == locale && $0.displayType == displayType }
    }

    /// Replaces the language's set on that device; nil forgets it.
    mutating func setHandSet(_ set: ScreenshotHandSet?, locale: String, displayType: ScreenshotDisplayType) {
        var sets = (handSets ?? []).filter { !($0.locale == locale && $0.displayType == displayType) }
        if let set { sets.append(set) }
        handSets = sets.isEmpty ? nil : sets
    }

    /// Forgets every hand edit in `locale`, e.g. when its kept
    /// screenshots are restored.
    mutating func removeHandSets(locale: String) {
        let sets = (handSets ?? []).filter { $0.locale != locale }
        handSets = sets.isEmpty ? nil : sets
    }

    /// Every file a set or a waiting suggestion still uses.
    var handFileIDs: Set<String> {
        let inSets = (handSets ?? []).reduce(into: Set<String>()) { $0.formUnion($1.fileIDs) }
        return inSets.union((handProposals ?? []).filter(\.isWaiting).map(\.file.id))
    }
}
