//
//  ProductPageScreenshotsBox.swift
//  Atlas
//

import SwiftUI

/// The screenshots and App Previews the page shows in one language, on
/// iPhone or iPad: its own, the set made for it waiting in Review & Push,
/// or the default page's. Make Screenshots for This Page… makes it a set of
/// its own (board 52); App Previews are changed in App Store Connect.
struct ProductPageScreenshotsBox: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let locale: String

    var body: some View {
        let queued = viewModel.queuedScreenshots(of: page, locale: locale, device: viewModel.device)
        let isOwn = queued != nil || viewModel.hasOwnScreenshots(page, locale: locale, device: viewModel.device)
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Text("Screenshots and App Previews")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("Device", selection: $viewModel.device) {
                    ForEach(ProductPageDevice.allCases) { device in
                        Text(device.title).tag(device)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("pages.screenshots.device")
                source(isOwn: isOwn)
            }
            if let queued {
                PageShotsQueuedStrip(files: queued, device: viewModel.device, height: viewModel.device == .iPad ? 132 : 172)
            } else {
                ProductPageScreenshotStrip(
                    viewModel: viewModel,
                    state: viewModel.shownScreenshots(of: page, locale: locale, device: viewModel.device),
                    device: viewModel.device,
                    height: viewModel.device == .iPad ? 132 : 172,
                    isOwn: isOwn
                )
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(note(queued: queued))
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("pages.screenshots.note")
                PageShotsMakeButton(viewModel: viewModel, page: page)
            }
            PageShotsRunRow(viewModel: viewModel, page: page)
            if !isOwn, viewModel.pageShotsRun(of: page) == nil, let brief = viewModel.brief(of: page) {
                ProductPageBriefNote(viewModel: viewModel, page: page, brief: brief)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.screenshotsBox")
    }

    private func note(queued: [ProductPageScreenshotsPush.File]?) -> String {
        guard let queued else { return viewModel.screenshotsNote(of: page, locale: locale, device: viewModel.device) }
        let name = ProductPageChangeBuilder.localeName(locale)
        return queued.count == 1
            ? String(localized: "1 screenshot made for this page, in \(name), waiting in Review & Push.")
            : String(localized: "\(queued.count) screenshots made for this page, in \(name), waiting in Review & Push.")
    }

    /// Same as Default · Own: which the language shows, not a control.
    private func source(isOwn: Bool) -> some View {
        HStack(spacing: 0) {
            segment(String(localized: "Same as Default"), isOn: !isOwn)
            segment(String(localized: "Own"), isOn: isOwn)
        }
        .padding(2)
        .background(Palette.fill1, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isOwn ? "Its own screenshots" : "Same as the default page"))
        .accessibilityIdentifier("pages.screenshots.source")
    }

    private func segment(_ title: String, isOn: Bool) -> some View {
        Text(title)
            .font(.caption.weight(isOn ? .semibold : .regular))
            .foregroundStyle(isOn ? Palette.label : Palette.label2)
            .padding(.horizontal, Spacing.small)
            .frame(height: 20)
            .background(isOn ? AnyShapeStyle(Palette.raised) : AnyShapeStyle(Color.clear), in: Capsule())
    }
}
