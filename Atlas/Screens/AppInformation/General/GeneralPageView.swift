//
//  GeneralPageView.swift
//  Atlas
//

import SwiftUI

/// General: category and content rights for the whole app; copyright and
/// release for the version picked in the version menu.
struct GeneralPageView: View {
    @Bindable var viewModel: AppInformationViewModel
    @FocusState private var isCopyrightFocused: Bool

    var body: some View {
        if let content = viewModel.content, let general = viewModel.general {
            // Each field says where it shows (board 88).
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                AppInformationSuggestionsPanel(viewModel: viewModel, page: .general)
                if showsCategories {
                    categorySection(general)
                }
                if viewModel.showsField(.contentRights) {
                    contentRightsSection(general)
                }
                if let version = content.version, showsVersion {
                    versionSection(general, content: content, version: version)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appInformation.general")
            .onChange(of: viewModel.focusRequest, initial: true) {
                guard viewModel.focusRequest == .copyright else { return }
                isCopyrightFocused = true
                viewModel.focusRequest = nil
            }
        }
    }

    /// With "Only fields with suggestions or changes" on, a section shows
    /// while one of its suggestion fields does.
    private var showsCategories: Bool {
        let fields: [AppInformationSuggestionField] = [.primaryCategory, .secondaryCategory, .gamesSubcategories, .secondaryGamesSubcategories]
        return fields.contains { viewModel.showsField($0) }
    }

    private var showsVersion: Bool {
        viewModel.showsField(.copyright) || viewModel.showsField(.release)
    }

    private func categorySection(_ general: GeneralValues) -> some View {
        AppInformationFormSection(title: String(localized: "Category")) {
            if viewModel.showsField(.primaryCategory) {
                AppInformationFormRow(
                    label: String(localized: "Primary"),
                    whereShown: AppInformationFieldPlacement.primaryCategory(appName: viewModel.app.name)
                ) {
                    CategoryPicker(title: String(localized: "Primary category"), selection: general.primaryCategory, categories: AppCategory.all) {
                        viewModel.setPrimaryCategory($0)
                    }
                    .accessibilityIdentifier("appInformation.general.primaryCategory")
                }
                AppInformationFieldSuggestions(viewModel: viewModel, field: .primaryCategory)
            }
            if viewModel.showsField(.secondaryCategory) {
                if viewModel.showsField(.primaryCategory) { Divider() }
                AppInformationFormRow(
                    label: String(localized: "Secondary"),
                    detail: String(localized: "· optional"),
                    whereShown: AppInformationFieldPlacement.secondaryCategory(appName: viewModel.app.name)
                ) {
                    CategoryPicker(
                        title: String(localized: "Secondary category"),
                        selection: general.secondaryCategory,
                        categories: AppCategory.all.filter { $0.id != general.primaryCategory },
                        allowsNone: true
                    ) { viewModel.setSecondaryCategory($0) }
                        .accessibilityIdentifier("appInformation.general.secondaryCategory")
                }
                AppInformationFieldSuggestions(viewModel: viewModel, field: .secondaryCategory)
            }
            if general.isGame, viewModel.showsField(.gamesSubcategories) {
                Divider()
                subcategoryRow(general, secondary: false)
            }
            if general.isSecondaryGame, viewModel.showsField(.secondaryGamesSubcategories) {
                Divider()
                subcategoryRow(general, secondary: true)
            }
        }
    }

    /// Up to two Games subcategories: the primary category's, or under
    /// Secondary the secondary category's, while it's Games.
    @ViewBuilder
    private func subcategoryRow(_ general: GeneralValues, secondary: Bool) -> some View {
        let selected = secondary ? general.secondaryGamesSubcategories : general.gamesSubcategories
        let identifier = secondary ? "appInformation.general.secondaryGamesSubcategory" : "appInformation.general.gamesSubcategory"
        AppInformationFormRow(
            label: secondary ? String(localized: "Secondary Games subcategories") : String(localized: "Games subcategories"),
            detail: String(localized: "· up to two"),
            whereShown: AppInformationFieldPlacement.gamesSubcategories(appName: viewModel.app.name)
        ) {
            // Side by side, or one under the other where two don't fit.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.small) { subcategoryPickers(selected, secondary: secondary, identifier: identifier) }
                VStack(alignment: .trailing, spacing: Spacing.small) { subcategoryPickers(selected, secondary: secondary, identifier: identifier) }
            }
        }
        AppInformationFieldSuggestions(viewModel: viewModel, field: secondary ? .secondaryGamesSubcategories : .gamesSubcategories)
    }

    /// The two Games subcategory pop-ups.
    private func subcategoryPickers(_ selected: [String], secondary: Bool, identifier: String) -> some View {
        ForEach(0..<2, id: \.self) { index in
            CategoryPicker(
                title: secondary
                    ? String(localized: "Secondary Games subcategory \(index + 1)")
                    : String(localized: "Games subcategory \(index + 1)"),
                selection: selected.indices.contains(index) ? selected[index] : nil,
                categories: AppCategory.gamesSubcategories,
                allowsNone: true
            ) { viewModel.setGamesSubcategory($0, at: index, secondary: secondary) }
                .disabled(index > selected.count)
                .accessibilityIdentifier("\(identifier)\(index + 1)")
        }
    }

    private func contentRightsSection(_ general: GeneralValues) -> some View {
        AppInformationFormSection(title: String(localized: "Content rights")) {
            AppInformationFormRow(
                label: String(localized: "Does the app contain, show or access third-party content?"),
                whereShown: AppInformationFieldPlacement.onlyApple
            ) {
                YesNoPicker(title: String(localized: "Third-party content"), value: general.contentRights.map { $0 == .usesThirdPartyContent }) {
                    viewModel.setContentRights($0 ? .usesThirdPartyContent : .doesNotUseThirdPartyContent)
                }
                .accessibilityIdentifier("appInformation.general.thirdPartyContent")
            }
            AppInformationFieldSuggestions(viewModel: viewModel, field: .contentRights)
            if general.contentRights == .usesThirdPartyContent {
                Divider()
                AppInformationFormRow(label: String(localized: "I have the rights to use it, or it’s otherwise permitted")) {
                    Toggle(
                        String(localized: "Rights confirmed"),
                        isOn: Binding(get: { general.rightsConfirmed }, set: { viewModel.setRightsConfirmed($0) })
                    )
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .accessibilityIdentifier("appInformation.general.rightsConfirmed")
                }
            }
        }
    }

    private func versionSection(_ general: GeneralValues, content: AppInformationContent, version: StorePageVersion) -> some View {
        AppInformationFormSection(title: String(localized: "Version \(version.versionString)")) {
            if viewModel.showsField(.copyright) {
                AppInformationFormRow(label: String(localized: "Copyright"), whereShown: AppInformationFieldPlacement.informationSection) {
                    TextField(
                        String(localized: "Copyright"),
                        text: Binding(get: { general.copyright }, set: { viewModel.setCopyright($0) }),
                        prompt: Text("© 2026 Your Company")
                    )
                    .labelsHidden()
                    // Narrower in the smallest window, so the row fits.
                    .frame(minWidth: 160, maxWidth: 260)
                    .focused($isCopyrightFocused)
                    .disabled(!content.isVersionEditable)
                    .accessibilityIdentifier("appInformation.general.copyright")
                }
                AppInformationFieldSuggestions(viewModel: viewModel, field: .copyright)
            }
            if viewModel.showsField(.release) {
                if viewModel.showsField(.copyright) { Divider() }
                releaseRows(general, content: content)
            }
            if !content.isVersionEditable {
                Divider()
                ReadOnlyVersionNote(version: version, editable: content.editableVersion)
            }
        } trailing: {
            AppInformationVersionMenu(versions: content.versions, selected: version) { id in
                Task { await viewModel.selectVersion(id) }
            }
        }
    }

    @ViewBuilder
    private func releaseRows(_ general: GeneralValues, content: AppInformationContent) -> some View {
        AppInformationFormRow(label: String(localized: "Release"), whereShown: AppInformationFieldPlacement.onlyApple) {
            let selection = Binding(get: { general.release }, set: { $0.map(viewModel.setRelease) })
            // Segments as wide as their titles: SwiftUI's segmented style
            // makes all three as wide as "Automatically after approval",
            // which left the row's label no room. Where even those don't
            // fit (the 860 pt window), a pop-up: the segments' rigid width
            // made the page wider than the window, cut on both sides.
            ViewThatFits(in: .horizontal) {
                FittingSegmentedPicker(
                    label: String(localized: "Release"),
                    options: ReleaseOption.allCases.map { (value: ReleaseOption?.some($0), title: $0.title) },
                    selection: selection
                )
                .fixedSize()
                Picker(String(localized: "Release"), selection: selection) {
                    ForEach(ReleaseOption.allCases, id: \.self) { option in
                        Text(option.title).tag(ReleaseOption?.some(option))
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            .disabled(!content.isVersionEditable)
            .accessibilityIdentifier("appInformation.general.release")
        }
        AppInformationFieldSuggestions(viewModel: viewModel, field: .release)
        if general.release == .scheduled {
            Divider()
            AppInformationFormRow(label: String(localized: "Release date"), detail: String(localized: "· earliest, after approval")) {
                DatePicker(
                    String(localized: "Release date"),
                    selection: Binding(get: { general.earliestReleaseDate ?? .now }, set: { viewModel.setReleaseDate($0) }),
                    in: Date.now...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .disabled(!content.isVersionEditable)
                .accessibilityIdentifier("appInformation.general.releaseDate")
            }
        }
    }
}
