//
//  ProductPageSubmitSheet.swift
//  Atlas
//

import SwiftUI

/// Submit for Review (board 54): what goes to Apple and Atlas's checks of
/// it, whether the page becomes visible once approved, and Submit for
/// Review. The page goes to App Review by itself; only the person submits.
struct ProductPageSubmitSheet: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage

    @State private var makesVisible = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Submit “\(page.name)” for Review")
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("pages.submit.title")
                Text("Only the page goes to App Review. \(viewModel.app.name)’s version and default page stay.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.xLarge)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    checks
                    afterApproval
                    Banner(
                        kind: .info,
                        title: String(localized: "Only you submit."),
                        message: String(localized: "An assistant can prepare a page, not push or submit it.")
                    )
                    if let error = viewModel.submitError {
                        Banner(kind: .apiError, title: error.summary, message: error.details, isInline: true)
                            .accessibilityIdentifier("pages.submit.error")
                    }
                }
                .padding(Spacing.xLarge)
            }
            Divider()
            footer
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.medium)
        }
        .frame(width: 540)
        .frame(minHeight: 420, idealHeight: 560, maxHeight: 680)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.submitSheet")
    }

    private var checks: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("What goes to Apple").font(.body.weight(.semibold))
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(viewModel.submitChecks(of: page)) { check in
                    ProductPageSubmitCheckRow(check: check)
                }
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
    }

    private var afterApproval: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("After approval").font(.body.weight(.semibold))
            HStack(alignment: .top, spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make the page visible when it’s approved")
                        .font(.callout)
                    Text("Off: approved but hidden until you turn Visible on, with no review.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Make the page visible when it’s approved", isOn: $makesVisible)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityIdentifier("pages.submit.visible")
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.medium) {
            Text("App Review usually answers within a day.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if viewModel.isSubmitting {
                ProgressView().controlSize(.small)
            }
            Button("Cancel") {
                viewModel.isSubmitPresented = false
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("pages.submit.cancel")
            Button("Submit for Review") {
                Task { await viewModel.submit(page, makeVisible: makesVisible) }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSubmitting || viewModel.submittableVersion(of: page) == nil)
            .accessibilityIdentifier("pages.submit.confirm")
        }
    }
}
