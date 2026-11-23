//
//  EnvironmentValues+SectionSummary.swift
//  Atlas
//

import SwiftUI

extension EnvironmentValues {
    /// The open section's summary line, which `SectionHeader` and App
    /// Information's page headers show under the description; nil hides it.
    @Entry var sectionSummary: SectionSummary?
}
