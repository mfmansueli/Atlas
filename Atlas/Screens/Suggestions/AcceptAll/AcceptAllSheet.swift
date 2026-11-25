//
//  AcceptAllSheet.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// Accept All Languages (or Pages) before it accepts anything: languages on
/// the left with a checkbox each, the chosen language's suggestions on the
/// right, and "Don't ask again" in the footer.
struct AcceptAllSheet: View {
    @State var selection: AcceptAllSelection
    let onCancel: () -> Void
    /// The ticked suggestions' ids, and whether to stop asking.
    let onAccept: (Set<String>, Bool) -> Void
    /// The capture a caption's screenshot before → after draws; nil for
    /// sheets without screenshots.
    let captureImage: (@MainActor (SlotPreview) -> CGImage?)?

    init(
        selection: AcceptAllSelection,
        onCancel: @escaping () -> Void,
        onAccept: @escaping (Set<String>, Bool) -> Void,
        captureImage: (@MainActor (SlotPreview) -> CGImage?)? = nil
    ) {
        _selection = State(initialValue: selection)
        self.onCancel = onCancel
        self.onAccept = onAccept
        self.captureImage = captureImage
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                groupsColumn
                Divider()
                itemsColumn
            }
            Divider()
            footer
        }
        .frame(width: 780, height: 620)
        .accessibilityIdentifier("acceptAll.sheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(selection.kind.title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(selection.subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, Spacing.medium)
    }

    private var groupsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                HStack(spacing: Spacing.tiny) {
                    Text(selection.kind.groupsTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.label2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("All") { selection.selectAll() }
                        .accessibilityIdentifier("acceptAll.all")
                    Button("None") { selection.selectNone() }
                        .accessibilityIdentifier("acceptAll.none")
                }
                .buttonStyle(.link)
                .font(.subheadline)
                .padding(.leading, Spacing.small)
                .padding(.trailing, Spacing.xxSmall)
                .padding(.bottom, Spacing.xSmall)
                ForEach(selection.groups) { group in
                    groupRow(group)
                }
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, 10)
        }
        .frame(width: 232)
    }

    private func groupRow(_ group: AcceptAllGroup) -> some View {
        HStack(spacing: Spacing.small) {
            AcceptAllCheckbox(state: selection.state(of: group), label: String(localized: "Include \(group.title)")) {
                selection.toggle(group)
            }
            .accessibilityIdentifier("acceptAll.group.\(group.id)")
            Button {
                selection.focusedGroupID = group.id
            } label: {
                HStack(spacing: Spacing.small) {
                    if let region = group.regionCode {
                        FlagTile(regionCode: region)
                            .frame(width: 20)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.title)
                            .lineLimit(1)
                        Text(groupCaption(group))
                            .font(.footnote)
                            .foregroundStyle(Palette.label2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.label3)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("acceptAll.focus.\(group.id)")
        }
        .padding(.leading, Spacing.small)
        .padding(.trailing, Spacing.xSmall)
        .padding(.vertical, Spacing.xxSmall)
        .background(
            group.id == selection.focusedGroupID ? AnyShapeStyle(Palette.fill2) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        )
    }

    private func groupCaption(_ group: AcceptAllGroup) -> String {
        var parts = [String(localized: "\(selection.selectedCount(in: group)) of \(group.items.count)")]
        if group.isNewPage { parts.append(String(localized: "new page")) }
        if group.soundsOffCount > 0 { parts.append(String(localized: "\(group.soundsOffCount) sounds off", comment: "kind:badge")) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var itemsColumn: some View {
        if let group = selection.focusedGroup {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.small) {
                    Text(group.title)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(selection.focusedCountText)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.label2)
                    Button(selection.focusedToggleTitle) { selection.toggleFocusedGroup() }
                        .controlSize(.regular)
                        .accessibilityIdentifier("acceptAll.toggleFocused")
                }
                .padding(.horizontal, Spacing.large)
                .padding(.top, Spacing.medium)
                .padding(.bottom, Spacing.small)
                if let text = selection.focusedNewPageText {
                    Banner(kind: .info, title: text, isInline: true) { EmptyView() }
                        .padding(.horizontal, Spacing.large)
                        .padding(.bottom, Spacing.small)
                }
                ScrollView {
                    VStack(spacing: Spacing.xSmall) {
                        ForEach(group.items) { item in
                            AcceptAllItemRow(
                                item: item, isSelected: selection.isSelected(item), isRightToLeft: group.isRightToLeft, captureImage: captureImage
                            ) {
                                selection.toggle(item)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.large)
                    .padding(.bottom, Spacing.medium)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $selection.dontAskAgain) {
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text(selection.kind.dontAskTitle)
                        .font(.subheadline)
                    Text("You can undo right after. Turn this back on next to the button or in Settings → Suggestions.")
                        .font(.footnote)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("acceptAll.dontAsk")
            Text(selection.summary)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Palette.label2)
                .fixedSize()
                .accessibilityIdentifier("acceptAll.summary")
            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("acceptAll.cancel")
            Button(selection.acceptTitle) {
                onAccept(selection.selected, selection.dontAskAgain)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selection.selectedCount == 0)
            .accessibilityIdentifier("acceptAll.accept")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, Spacing.medium)
    }
}

#Preview {
    AcceptAllSheet(
        selection: AcceptAllSelection(kind: .storePage, groups: [
            AcceptAllGroup(id: "en-US", title: "English (U.S.)", regionCode: "US", items: [
                AcceptAllItem(id: "1", title: "Subtitle", source: .builtIn, current: "Old", suggested: "New", reason: "Why."),
            ]),
            AcceptAllGroup(id: "he", title: "Hebrew", regionCode: "IL", isNewPage: true, isRightToLeft: true, items: [
                AcceptAllItem(id: "2", title: "Name", source: .assistant(client: "Claude Code"), current: "", suggested: "לומן", reason: "Why."),
            ]),
        ]),
        onCancel: {},
        onAccept: { _, _ in }
    )
}
