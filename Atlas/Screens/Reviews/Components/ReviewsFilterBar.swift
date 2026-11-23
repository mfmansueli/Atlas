//
//  ReviewsFilterBar.swift
//  Atlas
//

import SwiftUI

/// Above the list: Needs a Reply, 1–2 Stars, Replied and All, the group
/// being shown, the storefront and the order.
struct ReviewsFilterBar: View {
    @Bindable var viewModel: ReviewsViewModel

    var body: some View {
        HStack(spacing: Spacing.small) {
            // A segmented control, not blue buttons (README — Design
            // system §4): none is selected while a group is shown.
            Picker("Show", selection: filterSelection) {
                ForEach(ReviewFilter.allCases) { filter in
                    Text(segmentTitle(filter)).tag(Optional(filter))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("reviews.filter")
            if let theme = viewModel.selectedTheme {
                themePill(theme)
            }
            Spacer(minLength: Spacing.small)
            territoryMenu
            sortMenu
        }
        // The filter row's controls are row-sized (24 pt), like the prototype's.
        .controlSize(.regular)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.filterBar")
    }

    private var filterSelection: Binding<ReviewFilter?> {
        Binding {
            viewModel.themeFilter == nil ? viewModel.filter : nil
        } set: { filter in
            guard let filter else { return }
            viewModel.themeFilter = nil
            viewModel.filter = filter
        }
    }

    private func segmentTitle(_ filter: ReviewFilter) -> String {
        guard let count = viewModel.count(for: filter) else { return filter.title }
        return "\(filter.title) \(count.formatted())"
    }

    /// "A dark widget ×": the group "Show Reviews" opened.
    private func themePill(_ theme: ReviewTheme) -> some View {
        HStack(spacing: Spacing.xxSmall) {
            Text(theme.title)
                .font(.callout)
                .lineLimit(1)
            Button {
                viewModel.show(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Clear"))
            .accessibilityIdentifier("reviews.filter.theme.clear")
        }
        .padding(.leading, 10)
        .padding(.trailing, Spacing.small)
        .frame(height: 24)
        .background(Palette.fill2, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.filter.theme")
    }

    private var territoryMenu: some View {
        Menu {
            Button("All Countries") { viewModel.territoryFilter = nil }
            Divider()
            ForEach(viewModel.territories, id: \.code) { territory in
                Button("\(TerritoryCatalog.standard.territory(alpha2: territory.code)?.name ?? territory.code) (\(territory.count))") {
                    viewModel.territoryFilter = territory.code
                }
            }
        } label: {
            if let code = viewModel.territoryFilter {
                Label {
                    Text(TerritoryCatalog.standard.territory(alpha2: code)?.name ?? code)
                } icon: {
                    Text(FlagTile.flag(for: code) ?? "")
                }
            } else {
                Text("All Countries")
            }
        }
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .fixedSize()
        .accessibilityIdentifier("reviews.territoryMenu")
    }

    private var sortMenu: some View {
        Menu(viewModel.sort.title) {
            Picker("Order", selection: $viewModel.sort) {
                ForEach(ReviewSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .fixedSize()
        .accessibilityIdentifier("reviews.sortMenu")
    }
}
