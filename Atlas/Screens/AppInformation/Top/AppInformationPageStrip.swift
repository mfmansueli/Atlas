//
//  AppInformationPageStrip.swift
//  Atlas
//

import SwiftUI

/// App Information's seven pages as a strip of cards that scrolls
/// sideways (board 88), under the top: each card's symbol, name and state
/// ("3 suggested", "2 need you", "Ready"), with "Only Apple sees" before
/// App Review and Export Compliance. Opening a page scrolls its card into
/// view. Cards are `appInformation.page.<page>`.
struct AppInformationPageStrip: View {
    @Bindable var viewModel: AppInformationViewModel

    var body: some View {
        PageCardStrip(
            items: AppInformationPageCards.items { viewModel.pageStatus(for: $0) },
            selection: $viewModel.page,
            label: String(localized: "App Information pages", comment: "kind:label · VoiceOver name of the page strip"),
            identifier: "appInformation.page"
        )
    }
}
