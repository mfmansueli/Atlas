//
//  OfferSheetChrome.swift
//  Atlas
//

import SwiftUI

/// What the promotional offer, win-back offer and offer code sheets share
/// with Add Introductory Offer…: a title and what it's for, a grouped form,
/// the problems once Add was tried, and Cancel / Add to Review & Push.
struct OfferSheetChrome<Content: View>: View {
    let title: String
    let detail: String
    let footnote: String
    /// `pricing.promotionalOffer`: the sheet's identifier and its controls' prefix.
    let identifier: String
    let problems: [SubscriptionOfferProblem]
    @Binding var showsProblems: Bool
    var addTitle = String(localized: "Add to Review & Push")
    let onCancel: () -> Void
    let onAdd: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Form {
                content()
                if showsProblems, !problems.isEmpty { problemSection }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            Divider()
            footer
        }
        .frame(width: 540)
        .frame(minHeight: 420, idealHeight: 640, maxHeight: 720)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.xLarge)
    }

    private var problemSection: some View {
        Section {
            ForEach(problems, id: \.self) { problem in
                Text(problem.message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.err)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier).problems")
    }

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            Text(footnote)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("\(identifier).cancel")
            Button(addTitle) {
                guard problems.isEmpty else {
                    showsProblems = true
                    return
                }
                onAdd()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("\(identifier).add")
        }
        .buttonBorderShape(.capsule)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
    }
}
