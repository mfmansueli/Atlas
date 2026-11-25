//
//  CountryNotPushedPill.swift
//  Atlas
//

import SwiftUI

/// "Not pushed": a country's change waits in Review & Push.
struct CountryNotPushedPill: View {
    var body: some View {
        Pill(text: String(localized: "Not pushed", comment: "kind:pill"), style: .accent)
            .fixedSize()
    }
}
