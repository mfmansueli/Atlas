//
//  Font+TextStyles.swift
//  Atlas
//

import SwiftUI

/// The ten text styles (README — Design system §3). Nine are macOS's own
/// and are written as the system's: `.largeTitle.bold()`, `.title`,
/// `.title2` and `.title3` with `.weight(.semibold)`, Headline as
/// `.body.weight(.semibold)`, `.body`, `.callout`, `.subheadline` and
/// `.footnote` (counters and timestamps only). Display is the tenth.
extension Font {
    /// Welcome's title only: 32 pt bold.
    static let display = Font.system(size: 32, weight: .bold)
}
