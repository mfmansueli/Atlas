//
//  EventArtworkConceptChecks.swift
//  Atlas
//

import Foundation

/// The Check step's four lines for a concept, from the checks of its
/// stills: nothing busy under the text, the text reads (the lower part
/// dark enough for Apple's white text), no words in the art (or, with
/// words on, the event's name drawn in each language), and the sizes
/// Apple asks for.
enum EventArtworkConceptChecks {
    static func make(_ reports: [InAppEventArtworkReport], wordsInArt: Bool) -> [EventArtworkConceptCheck] {
        let looks = reports.compactMap(\.look)
        let busy = reports.filter { $0.look?.isLowerPartBusy == true }.map(\.kind.title)
        let bright = reports.filter { $0.look?.isLowerPartBright == true }.map(\.kind.title)
        let worded = Array(Set(looks.flatMap(\.text))).sorted().prefix(3)
        let refused = reports.flatMap(\.checks).filter(\.isRefusal)
        var checks = [
            EventArtworkConceptCheck(
                title: String(localized: "Nothing important under the text"),
                detail: busy.isEmpty
                    ? String(localized: "The lower third is calm on both images.")
                    : String(localized: "The lower part of the \(list(busy)) is busy where Apple writes the name."),
                isOK: busy.isEmpty
            ),
            EventArtworkConceptCheck(
                title: String(localized: "The text reads on the art"),
                detail: bright.isEmpty
                    ? String(localized: "White text has the contrast it needs.")
                    : String(localized: "The lower part of the \(list(bright)) is light: Apple’s white text may not read."),
                isOK: bright.isEmpty
            ),
        ]
        if wordsInArt {
            checks.append(EventArtworkConceptCheck(
                title: String(localized: "The name drawn in each language"),
                detail: String(localized: "Apple asks for no words in the art; here they’re drawn in each language on purpose."),
                isOK: true
            ))
        } else {
            checks.append(EventArtworkConceptCheck(
                title: String(localized: "No words in the art"),
                detail: worded.isEmpty
                    ? String(localized: "The App Store writes the text in every language.")
                    : String(localized: "Found \(worded.map { "“\($0)”" }.joined(separator: ", ")) in the art."),
                isOK: worded.isEmpty
            ))
        }
        let sizes = unique(reports.map(\.file.pixelSize.title)).joined(separator: String(localized: " and "))
        checks.append(EventArtworkConceptCheck(
            title: String(localized: "Sizes Apple asks for"),
            detail: refused.isEmpty ? sizes : refused.map(\.text).joined(separator: " "),
            isOK: refused.isEmpty
        ))
        return checks
    }

    private static func list(_ kinds: [String]) -> String {
        unique(kinds).map { $0.lowercased() }.joined(separator: String(localized: " and "))
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
