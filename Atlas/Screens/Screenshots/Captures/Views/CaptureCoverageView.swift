//
//  CaptureCoverageView.swift
//  Atlas
//

import SwiftUI
import UniformTypeIdentifiers

/// After an import (design `capt`): every localized locale's raw captures
/// on the current display type, with where they came from and whether the
/// interface is the locale's own. A click on one shows it large; ⌘-click,
/// a row or a column selects captures to replace or capture again.
struct CaptureCoverageView: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let coverage: CaptureCoverage
    /// The capture the viewer last showed, kept while it closes.
    @State private var lastViewed: CaptureViewerTarget?

    static let localeWidth: CGFloat = 190
    static let sourceWidth: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider()
            if !viewModel.captures.selection.isEmpty {
                CaptureSelectionBar(captures: viewModel.captures)
                Divider()
            }
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(coverage.groups) { group in
                            groupHeader(group)
                            ForEach(group.rows) { row in
                                CaptureCoverageRowView(
                                    row: row, thumbnailWidth: thumbnailWidth, images: viewModel.captureImages,
                                    isSelected: { viewModel.captures.isSelected($0, of: row) },
                                    onView: { viewModel.captures.view($0, of: row) },
                                    onToggle: { viewModel.captures.toggle($0, of: row) },
                                    onToggleRow: { viewModel.captures.toggleRow(row) },
                                    onReplace: { cell, url in
                                        let key = viewModel.captures.key(cell, of: row)
                                        Task { await viewModel.captures.replace(key, with: url) }
                                    }
                                )
                                Divider()
                            }
                        }
                    } header: {
                        columns
                    }
                }
                .frame(minWidth: minimumWidth, alignment: .leading)
            }
            .leavesChatRoom()
        }
        // Presented while a capture is viewed, not per capture: stepping
        // to another one keeps the same sheet.
        .sheet(isPresented: isViewing) {
            if let target = viewModel.captures.viewed ?? lastViewed {
                CaptureViewerSheet(viewModel: viewModel, target: target)
            }
        }
        .onChange(of: viewModel.captures.viewed) { _, viewed in
            if let viewed { lastViewed = viewed }
        }
        .onChange(of: viewModel.displayType) { viewModel.captures.clearSelection() }
        .fileImporter(isPresented: $viewModel.captures.isReplaceImporterPresented, allowedContentTypes: [.png, .image]) { result in
            guard case let .success(url) = result, let cell = viewModel.captures.replaceTarget else { return }
            Task { await viewModel.captures.replace(cell, with: url, securityScoped: true) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("captures.coverage")
    }

    private var isViewing: Binding<Bool> {
        Binding { viewModel.captures.viewed != nil } set: { if !$0 { viewModel.captures.viewed = nil } }
    }

    private var thumbnailWidth: CGFloat { viewModel.displayType.thumbnailWidth(phone: 40, tablet: 74) }

    private var columnWidth: CGFloat { thumbnailWidth + 24 }

    private var minimumWidth: CGFloat {
        Self.localeWidth + Self.sourceWidth + CGFloat(coverage.slotNames.count) * columnWidth + Spacing.xxLarge
    }

    private var bar: some View {
        HStack(spacing: Spacing.medium) {
            Button("Import More…") { viewModel.captures.isImporterPresented = true }
                .controlSize(.regular)
                .accessibilityIdentifier("captures.importMore")
            Text(coverage.summary)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("captures.summary")
            Spacer(minLength: Spacing.medium)
            HStack(spacing: Spacing.xSmall) {
                InterfaceChip()
                Text(coverage.legend)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.xSmall)
    }

    private var columns: some View {
        HStack(spacing: 0) {
            Text("Locale").frame(width: Self.localeWidth, alignment: .leading)
            Text("Source").frame(width: Self.sourceWidth, alignment: .leading)
            ForEach(Array(coverage.slotNames.enumerated()), id: \.offset) { index, name in
                Button { viewModel.captures.toggleColumn(index) } label: {
                    Text("\(Text(verbatim: "\(index + 1)").foregroundStyle(Palette.label)) \(name)")
                        .lineLimit(1)
                        .frame(width: columnWidth, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Text("Select \(name) in every language"))
                .accessibilityIdentifier("captures.coverage.column.\(index + 1)")
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Palette.label2)
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.content)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func groupHeader(_ group: CaptureCoverage.Group) -> some View {
        HStack(spacing: Spacing.xSmall) {
            Text(group.title)
                .textCase(.uppercase)
            Text(verbatim: "\(group.rows.count)")
                .foregroundStyle(Palette.label2)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.label2)
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.medium)
        .padding(.bottom, Spacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}
