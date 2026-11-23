//
//  PrivacyDataTypeRow.swift
//  Atlas
//

import SwiftUI

/// One data type in its own box: collected or not, who answered, how sure
/// and where it stands; for a collected type its purposes, whether it's
/// linked and used for tracking; the assistant's reason, its evidence, and
/// Reject and Accept for a suggestion nobody reviewed (the box tinted
/// purple); then a conflict to settle.
struct PrivacyDataTypeRow: View {
    @Bindable var viewModel: AppPrivacyViewModel
    let type: PrivacyDataType
    var isMismatched = false

    var body: some View {
        let entry = viewModel.worksheet[type]
        let answer = entry?.answer ?? .notCollected
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Text(type.name)
                    .font(.callout.weight(.semibold))
                    .layoutPriority(1)
                collectedPicker(answer)
                Spacer(minLength: 0)
                if let entry {
                    sourceTag(entry)
                    if let suggestion = entry.suggestion, entry.status != .yours || entry.conflict == nil {
                        PrivacyConfidenceBadge(confidence: suggestion.confidence)
                    }
                    PrivacyRowStatusPill(status: entry.status)
                }
            }
            if answer.collected {
                PrivacyPurposeToggles(answer: answer) { viewModel.togglePurpose($0, for: type) }
                if answer.isMissingPurpose {
                    InlineMessage.warning(String(localized: "Pick at least one purpose."))
                        .font(.subheadline)
                        .accessibilityIdentifier("appInformation.appPrivacy.type.\(type.rawValue).noPurpose")
                }
                PrivacyLinkageLine(type: type, answer: answer, viewModel: viewModel)
            }
            if let entry, entry.status.isAssistants, let rationale = entry.suggestion?.rationale {
                Text(rationale)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let entry {
                PrivacyDataTypeReviewLine(viewModel: viewModel, type: type, entry: entry)
            }
            if let entry, let conflict = entry.conflict {
                PrivacyConflictBox(yours: entry.answer, theirs: conflict) {
                    viewModel.keepYours(type)
                } onUseTheirs: {
                    viewModel.useAssistants(type)
                }
                .accessibilityIdentifier("appInformation.appPrivacy.type.\(type.rawValue).conflict")
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small + 2)
        .background(background(entry), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(isMismatched ? Palette.warnMark : Palette.separator, lineWidth: isMismatched ? 1.5 : 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityLabel(entry, answer: answer)))
        .accessibilityIdentifier("appInformation.appPrivacy.type.\(type.rawValue)")
    }

    private func collectedPicker(_ answer: PrivacyAnswer) -> some View {
        Picker(type.name, selection: Binding(get: { answer.collected }, set: { viewModel.setCollected(type, $0) })) {
            Text("Not collected").tag(false)
            Text("Collected").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .controlSize(.regular)
        .accessibilityIdentifier("appInformation.appPrivacy.type.\(type.rawValue).collected")
    }

    /// The assistant's chip while the answer is its, or "You".
    @ViewBuilder
    private func sourceTag(_ entry: PrivacyTypeEntry) -> some View {
        if let client = entry.client {
            AssistantChip(name: client)
        } else {
            Text("You")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
    }

    private func background(_ entry: PrivacyTypeEntry?) -> Color {
        if isMismatched { return Palette.warnTint }
        return entry?.status == .unreviewed ? Palette.aiSurface : Palette.raised
    }

    private func accessibilityLabel(_ entry: PrivacyTypeEntry?, answer: PrivacyAnswer) -> String {
        let state = answer.collected ? String(localized: "collected") : String(localized: "not collected")
        guard entry?.status == .unreviewed else { return "\(type.name): \(state)" }
        return String(localized: "\(type.name): \(state), suggestion not reviewed")
    }
}
