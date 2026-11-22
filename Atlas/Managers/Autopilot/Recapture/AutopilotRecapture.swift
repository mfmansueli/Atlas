//
//  AutopilotRecapture.swift
//  Atlas
//

import Foundation

/// A capture-only run: the app's last run opened again to redo only some
/// of its captures (Alba's 18 Japanese screens after its phrases were
/// rewritten) and, with them, moments of its App Preview. Plan and Design
/// are skipped: the plan, the template, the captions and the look stay as
/// they are, the other captures are reused, Pick shows only the ones
/// redone, and the new captures take the old ones' places in the set, so
/// Review & Push sends only the images they change. Cancel gives the run
/// back as it was.
struct AutopilotRecapture: Codable, Hashable, Sendable {
    /// The captures redone: each screen on a device in a language (and an
    /// iPhone Duo pose), as the plan's targets are.
    var targets: [AutopilotCaptureTarget]
    /// The App Preview's moments recorded again, by screen ID.
    var momentIDs: [String] = []
    /// Why, in a sentence the person reads: "phrases rewritten in d038b58".
    var reason: String?
    /// What shows it: a file, a commit.
    var evidence: String?
    /// The assistant that asked for it; nil when the person did.
    var client: String?
    /// The request it came from, when it waited in the queue.
    var requestID: String?
    /// When it opened: captures of its targets from before don't count.
    var openedAt: Date
    /// The run's end, its Review & Push and its last stage before it
    /// opened, given back by Cancel.
    var previousFinishedAt: Date?
    var previousReview: AutopilotGuidedReview?
    /// The captures the redone screens had when it opened: they stop
    /// counting, Pick shows them beside the new ones, and Cancel puts them
    /// back (a new capture of the same attempt takes an old one's place in
    /// the run).
    var previousCaptures: [AutopilotCapture] = []
    /// The App Preview's earlier takes of the moments recorded again.
    var previousRetakes: [AutopilotRecording]?
    /// The captures picked at Pick, by target (`AutopilotCaptureTarget.key`);
    /// a target without one takes its best new capture.
    var picks: [String: String] = [:]
    /// When the new captures went into the set; nil while it runs.
    var placedAt: Date?
    /// The app had no saved run: this one was made from the set's captures
    /// (`AutopilotRecapturePlanFromCaptures`), and Cancel takes it away
    /// again. Nil for a saved run opened again.
    var madeFromCaptures: Bool?

    /// Whether `target` is one of the captures redone.
    func covers(_ target: AutopilotCaptureTarget) -> Bool {
        targets.contains(target)
    }

    /// The languages redone, in the order they came.
    var locales: [String] {
        var seen: Set<String> = []
        return targets.map(\.locale).filter { seen.insert($0).inserted }
    }

    /// "18 captures in ja", "3 captures in de-DE and fr-FR", "the App
    /// Preview's Today moment".
    var title: String {
        AutopilotRecaptureRequest.title(captures: targets.count, locales: locales, moments: momentIDs.count)
    }
}
