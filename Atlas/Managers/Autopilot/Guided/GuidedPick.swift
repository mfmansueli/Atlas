//
//  GuidedPick.swift
//  Atlas
//

import Foundation

/// The look the design source recommends, marked at Choose: "Claude’s
/// pick" with Claude Design, the starters' "Atlas’s pick".
enum GuidedPick {
    /// "Claude", "Atlas": whose pick it is.
    static func title(design: DesignProjectKind) -> String {
        switch design {
        case .claudeDesign: "Claude"
        case _ where design.usesDesignAI: design.title
        default: "Atlas"
        }
    }

    /// "Claude’s pick".
    static func label(design: DesignProjectKind) -> String {
        String(localized: "\(title(design: design))’s pick")
    }

    /// The direction marked: the first to arrive, which the design source
    /// sends as its strongest; the one an unattended Choose takes.
    static func direction(in run: AutopilotRun) -> AutopilotDirection? {
        run.directions.first
    }

    /// The header concept marked: the one the design source recommends,
    /// else the first.
    static func concept(in run: AutopilotRun) -> AutopilotArtworkConcept? {
        run.recommendedConcept
    }
}
