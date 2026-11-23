//
//  StorePageSkeleton.swift
//  Atlas
//

import SwiftUI

/// The first load: a placeholder context bar and coverage rows.
struct StorePageSkeleton: View {
    var showsContextBar = true

    var body: some View {
        VStack(spacing: 0) {
            if showsContextBar {
                SectionBar {
                    HStack(spacing: Spacing.small) {
                        SkeletonBlock(width: 28, height: 28, cornerRadius: Radius.menuRow)
                        VStack(alignment: .leading, spacing: 5) {
                            SkeletonBlock(width: 220, height: 11)
                            SkeletonBlock(width: 320, height: 8)
                        }
                    }
                } trailing: {
                    SkeletonBlock(width: 320, height: 22, cornerRadius: Radius.banner)
                }
            }
            StorePageTableSkeleton()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Store page, loading"))
        .accessibilityIdentifier("storePage.skeleton")
    }
}
