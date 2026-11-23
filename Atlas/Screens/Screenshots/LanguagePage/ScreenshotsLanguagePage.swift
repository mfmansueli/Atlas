//
//  ScreenshotsLanguagePage.swift
//  Atlas
//

import SwiftUI

/// Screenshots, one language at a time: the header, the language bar, the
/// device, the template, Now | Suggested and Manage, the language's
/// screenshots large (a suggested caption drawn on its screenshot with a
/// purple ring) to select, move, replace, delete or add to by hand, and
/// each suggested caption to accept or dismiss. All Languages lists every
/// language instead.
struct ScreenshotsLanguagePage: View {
    @Bindable var viewModel: ScreenshotsViewModel

    @Environment(AppPreferences.self) private var preferences
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                ScreenshotsPageHeader(viewModel: viewModel)
                languageBar
                if viewModel.pageShowsAll {
                    ScreenshotsLanguageList(viewModel: viewModel)
                } else {
                    controls
                    shots
                    suggestions
                }
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("screenshots.page")
        .sheet(item: $viewModel.handSheet) { sheet in
            ScreenshotHandSheetView(viewModel: viewModel, sheet: sheet, locale: locale)
        }
    }

    private var locale: StoreLocale { viewModel.currentPageLocale }

    private var languageBar: some View {
        let model = viewModel.languageBarModel(acceptsRightAway: preferences.acceptsAllWithoutAsking)
        return LanguageBar(model: model, showsProChip: pro.isFree && model.withSuggestions.count > 1, picksInToolbar: true) { locale in
            viewModel.pageLocale = locale
            viewModel.pageShowsAll = false
        } onAcceptAll: {
            let languages = model.withSuggestions.count
            let accept = {
                _ = Task { await viewModel.acceptAllCaptions(withoutAsking: preferences.acceptsAllWithoutAsking) }
            }
            if languages > 1 {
                pro.require(.acceptAllLanguages(suggestions: model.totalCount, languages: languages), then: accept)
            } else {
                accept()
            }
        } onAcceptHere: {
            Task { await viewModel.acceptCaptionsHere() }
        } onAskFirst: {
            preferences.acceptsAllWithoutAsking = false
            viewModel.captionToast = ToastMessage(text: String(localized: "Accept All Languages will show you the suggestions first again."))
        } trailing: {
            EmptyView()
        }
    }

    private var controls: some View {
        FlowLayout(spacing: Spacing.small) {
            if viewModel.pageDisplays.count > 1 {
                Picker("Device", selection: $viewModel.displayType) {
                    ForEach(viewModel.pageDisplays, id: \.self) { display in
                        Text(display.title).tag(display)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("screenshots.page.device")
            }
            if let line = viewModel.templateLine {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            Picker("Captions", selection: $viewModel.showsSuggestedCaptions) {
                Text("Now").tag(false)
                Text("Suggested").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("screenshots.page.mode")
            ScreenshotHandManageMenu(viewModel: viewModel, locale: locale)
        }
        // The prototype's small segmented controls (`.seg.sm`) on this row.
        .controlSize(.small)
    }

    private var shots: some View {
        ScreenshotHandSetView(viewModel: viewModel, locale: locale, width: thumbnailWidth)
    }

    /// iPhone 142 pt wide; the wider devices' screenshots a bit wider.
    private var thumbnailWidth: CGFloat {
        switch viewModel.displayType {
        case .iPhone, .iPhoneDuo: 142
        case .watch: 110
        default: 210
        }
    }

    @ViewBuilder
    private var suggestions: some View {
        let captions = viewModel.proposedCaptions(in: locale)
        let files = viewModel.handProposals(locale: locale.code, displayType: viewModel.displayType)
        let arrangements = viewModel.handArrangements(locale: locale.code, displayType: viewModel.displayType)
        ForEach(arrangements) { arrangement in
            ScreenshotHandArrangementCard(viewModel: viewModel, arrangement: arrangement)
        }
        ForEach(files) { proposal in
            ScreenshotHandProposalCard(viewModel: viewModel, proposal: proposal)
        }
        if captions.isEmpty, !files.isEmpty || !arrangements.isEmpty {
            EmptyView()
        } else if captions.isEmpty {
            Text("Nothing to review in \(locale.name).")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("screenshots.page.nothing")
        } else {
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(captions) { caption in
                    ProposedCaptionCard(
                        caption: caption,
                        current: viewModel.currentHeadline(locale: caption.locale, slot: caption.slot),
                        isRightToLeft: locale.isRTL,
                        onDismiss: { Task { await viewModel.dismissCaption(caption) } },
                        onUseAndEdit: { Task { await viewModel.useAndEditCaption(caption) } },
                        // Immediate, so the caption leaves in the accept's spring.
                        onAccept: { Task.immediate { await viewModel.acceptCaption(caption) } }
                    )
                }
            }
        }
    }
}
