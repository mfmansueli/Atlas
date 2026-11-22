//
//  PageShotsResultStep.swift
//  Atlas
//

import SwiftUI

/// Result: the default page's set above the new one in a language, Atlas's
/// checks, and where the new set is used. Use These Screenshots puts them
/// in Review & Push; Ask for Changes… tells the assistant what to change,
/// and only this set is redone.
struct PageShotsResultStep: View {
    @Bindable var flow: PageShotsFlow
    let defaultSet: (String, ProductPageDevice) -> LoadState<[LiveScreenshot]>
    let viewModel: ProductPagesViewModel

    @State private var shownLocale: String?
    @State private var isAsking = false
    @State private var request = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    sets
                        .padding(.horizontal, Spacing.xLarge)
                        .padding(.vertical, Spacing.large)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xLarge) {
                        PageShotsChecks(flow: flow)
                        useSection
                    }
                    .padding(.horizontal, Spacing.xLarge)
                    .padding(.vertical, Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 300)
            }
            Divider()
            footer
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.medium)
        }
    }

    private var run: PageShotsRun? { flow.run }
    private var locale: String { shownLocale ?? run?.locales.first ?? flow.languages.first ?? "en-US" }
    private var display: ScreenshotDisplayType { run?.displays.first { $0 == shownDisplay } ?? run?.displays.first ?? .iPhone }
    @State private var shownDisplay: ScreenshotDisplayType?

    // MARK: - Sets

    private var sets: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                Picker("Language", selection: Binding { locale } set: { shownLocale = $0 }) {
                    ForEach(run?.locales ?? [], id: \.self) { code in
                        Text(ProductPageChangeBuilder.localeName(code)).tag(code)
                    }
                }
                .fixedSize()
                .accessibilityIdentifier("pages.shots.result.language")
                if (run?.displays.count ?? 0) > 1 {
                    Picker("Device", selection: Binding { display } set: { shownDisplay = $0 }) {
                        ForEach(run?.displays ?? [], id: \.self) { display in
                            Text(display.deviceName).tag(display)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("pages.shots.result.device")
                }
            }
            Text("DEFAULT PAGE")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.label2)
            ProductPageScreenshotStrip(
                viewModel: viewModel, state: defaultSet(locale, display == .iPad ? .iPad : .iPhone),
                device: display == .iPad ? .iPad : .iPhone, height: display == .iPad ? 120 : 170
            )
            .opacity(0.75)
            Text("“\(flow.page.name.uppercased())” · NEW")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .padding(.top, Spacing.xxSmall)
            newSet
            if let problem = run?.problem {
                InlineMessage.warning(problem)
                    .accessibilityIdentifier("pages.shots.resultProblem")
            }
        }
    }

    private var newSet: some View {
        let images = run?.images(locale: locale, displayType: display) ?? []
        let height: CGFloat = display == .iPad ? 120 : 170
        return ScrollView(.horizontal) {
            HStack(spacing: Spacing.xSmall) {
                ForEach(images) { image in
                    if let run {
                        PageShotsTile(
                            url: flow.studio.url(of: image, in: run), aspect: PageShotsTile.aspect(display), height: height,
                            overflows: !image.fits, label: String(localized: "New screenshot \(image.position + 1)")
                        )
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.shots.result.new")
    }

    // MARK: - Where it's used

    private var useSection: some View {
        let used = run?.useLocales ?? []
        let devices = run?.useDisplays ?? []
        return VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Use the new set in").font(.headline)
            FlowLayout(spacing: Spacing.xxSmall, lineSpacing: Spacing.xxSmall) {
                ForEach(run?.locales ?? [], id: \.self) { code in
                    PageShotsChip(
                        title: ProductPageChangeBuilder.localeName(code), regionCode: ProductPageChangeBuilder.region(code),
                        isOn: used.contains(code), identifier: "pages.shots.use.\(code)"
                    ) { flow.toggleUse(locale: code) }
                }
            }
            HStack(spacing: Spacing.xxSmall) {
                ForEach(run?.displays ?? [], id: \.self) { display in
                    PageShotsChip(
                        title: display.deviceName, isOn: devices.contains(display), identifier: "pages.shots.use.\(display.rawValue)"
                    ) { flow.toggleUse(display: display) }
                }
            }
            Text("Untick a language or a device to keep the default page’s screenshots there.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.medium) {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("pages.shots.useSummary")
            Button("Ask for Changes…") { isAsking = true }
                .popover(isPresented: $isAsking, arrowEdge: .top) { askPopover }
                .accessibilityIdentifier("pages.shots.ask")
            Button("Use These Screenshots") { flow.use() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(flow.usedCount == 0)
                .accessibilityIdentifier("pages.shots.use")
        }
    }

    private var summary: String {
        let count = flow.usedCount
        let shots = count == 1 ? String(localized: "1 screenshot goes") : String(localized: "\(count) screenshots go")
        return String(localized: "\(shots) to Review & Push. Nothing reaches the App Store until you push and submit the page.")
    }

    private var askPopover: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("What should change?").font(.headline)
            Text("Say it in a sentence. Only this page’s set is redone.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
            TextField("Open with search, and make the second caption shorter", text: $request, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("pages.shots.ask.text")
            HStack {
                Spacer()
                Button("Cancel") { isAsking = false }
                Button("Ask") {
                    let text = request
                    isAsking = false
                    request = ""
                    Task { await flow.askForChanges(text) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("pages.shots.ask.send")
            }
        }
        .padding(Spacing.large)
        .frame(width: 340)
    }
}
