//
//  TourTip.swift
//  Atlas
//

import SwiftUI
import TipKit

/// One of the tour's five tips as a TipKit `Tip` (README 01, board 63),
/// shown with `.popoverTip` on the control it explains and drawn by
/// `TourTipViewStyle` ("2 of 5" isn't part of TipKit's standard view).
///
/// Every start of the tour has its own tips (`run` is in the id): TipKit
/// remembers a tip it invalidated for good, and `Tips.resetDatastore()`
/// can't run once TipKit is configured (`tipsDatastoreAlreadyConfigured`),
/// so Show the Tour shows new tips instead of resetting the old ones.
struct TourTip: Tip {
    let step: TourStep
    /// The start of the tour this tip belongs to.
    let run: String
    let onNext: @MainActor @Sendable () -> Void
    let onAlternative: @MainActor @Sendable () -> Void
    let onClose: @MainActor @Sendable () -> Void

    var id: String { Self.id(step: step, run: run) }

    var title: Text { Text(step.title) }

    var message: Text? { Text(step.text) }

    var image: Image? { Image(systemName: step.systemImage) }

    var options: [any TipOption] {
        // The tour shows one tip right after another.
        Tips.IgnoresDisplayFrequency(true)
    }

    var actions: [Action] {
        Action(id: "next", title: step.nextTitle, perform: onNext)
        Action(id: "alternative", title: step.alternativeTitle, perform: onAlternative)
    }

    /// "tour.<run>.<number>".
    static func id(step: TourStep, run: String) -> String {
        "tour.\(run).\(step.number)"
    }

    /// TipKit, set up once at launch: tips show as soon as they're asked
    /// for, and the unit tests' host keeps its tips away from this Mac's.
    static func configureTipKit() {
        var options: [Tips.ConfigurationOption] = [.displayFrequency(.immediate)]
        #if DEBUG
        if UnitTestHost.isRunning {
            let url = FileManager.default.temporaryDirectory.appending(path: "AtlasTests-Tips", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            options.append(.datastoreLocation(.url(url)))
        }
        #endif
        try? Tips.configure(options)
    }
}
