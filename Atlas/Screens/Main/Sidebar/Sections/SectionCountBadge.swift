//
//  SectionCountBadge.swift
//  Atlas
//

import SwiftUI

/// A section's count: purple for suggestions to accept, gray for new
/// findings to read. Nothing at zero.
struct SectionCountBadge: View {
    let count: Int
    var isNeutral = false

    var body: some View {
        if count > 0 {
            if isNeutral {
                NeutralCountPill(count: count)
            } else {
                SuggestionBadge(count: count)
            }
        }
    }
}
