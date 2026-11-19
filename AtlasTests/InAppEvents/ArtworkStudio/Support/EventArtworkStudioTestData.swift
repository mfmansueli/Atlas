//
//  EventArtworkStudioTestData.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Runs and concepts for the board 47 tests, on the Winter Reflection
/// Challenge of `InAppEventsTestData` (English and German).
@MainActor
enum EventArtworkStudioTestData {
    typealias Events = InAppEventsTestData

    static var key: EventArtworkRun.Key { EventArtworkRun.Key(appID: Events.app.id, eventID: Events.winter.id) }

    static func run(step: EventArtworkStep = .making, style: EventArtworkStyle = .newLook, concepts: [EventArtworkConcept] = []) -> EventArtworkRun {
        var run = EventArtworkRun(
            appID: Events.app.id, eventID: Events.winter.id, eventName: Events.winter.referenceName, brief: "Snow on a path.", style: style,
            locales: ["en-US", "de-DE"]
        )
        run.step = step
        run.concepts = concepts
        return run
    }

    /// A concept with stills saved in `directory` (calm, or busy below).
    static func concept(_ id: String, isPick: Bool = false, busy: Bool = false, in directory: URL) throws -> EventArtworkConcept {
        var stills: [EventArtworkImage] = []
        for kind in InAppEventMedia.Kind.allCases {
            let size = InAppEventArtworkRules.minimumSize(for: kind)
            let fileID = try EventArtworkTestFiles.store(
                EventArtworkTestFiles.png(width: size.width, height: size.height, busy: busy), name: "\(id)-\(kind.mcpValue).png", in: directory
            )
            let url = try #require(InAppEventArtworkFiles.url(id: fileID, appID: Events.app.id, in: directory))
            stills.append(EventArtworkImage(kind: kind, fileID: fileID, path: url.path(percentEncoded: false)))
        }
        return EventArtworkConcept(
            id: id, name: "Concept \(id)", why: "Why \(id).", isPick: isPick, client: "Claude Code", stills: stills, arrivedAt: Events.now
        )
    }
}
