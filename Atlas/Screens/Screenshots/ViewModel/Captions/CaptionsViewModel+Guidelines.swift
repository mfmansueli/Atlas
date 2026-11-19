//
//  CaptionsViewModel+Guidelines.swift
//  Atlas
//

import Foundation

extension CaptionsViewModel {
    /// What App Review would reject in the caption being edited (kicker,
    /// headline and subhead): pricing such as “free” (2.3.7 names
    /// screenshots), other platforms, betas, placeholders, “coming soon”
    /// and “For Kids”. Assistants' captions are refused for it; the person
    /// is only warned, and can keep what they typed.
    var guidelineIssues: [StoreTextGuidelineIssue] {
        let headline = [kicker, headline].filter { !$0.isEmpty }.joined(separator: "\n")
        return StoreTextGuidelineCheck.issues(inCaption: headline, subhead: subhead)
    }
}
