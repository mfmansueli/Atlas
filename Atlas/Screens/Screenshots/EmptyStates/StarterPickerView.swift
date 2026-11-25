//
//  StarterPickerView.swift
//  Atlas
//

import SwiftUI

/// Sets with captures but no template: the template gallery, previewed
/// with the app's own captures. One template renders every locale the same
/// way.
struct StarterPickerView: View {
    @Bindable var viewModel: ScreenshotsViewModel
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text("Pick a template")
                        .font(.title3.weight(.semibold))
                    Text(intro)
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                TemplateStyleFilter(style: $viewModel.galleryStyle)
                TemplateGalleryGrid(
                    viewModel: viewModel,
                    isFirstRun: true,
                    onLocked: { starter in pro.require(.template) { Task { await viewModel.chooseStarter(starter) } } },
                    onUse: { starter in Task { await viewModel.chooseStarter(starter) } }
                )
            }
            .padding(Spacing.xxLarge)
        }
        .leavesChatRoom()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.starters")
    }

    private var intro: String {
        let summary = viewModel.captureSummary
        let rest = String(localized: "One template renders every locale alike; change anything later. Shown with sample captions.")
        return summary.isEmpty ? rest : summary + " " + rest
    }
}
