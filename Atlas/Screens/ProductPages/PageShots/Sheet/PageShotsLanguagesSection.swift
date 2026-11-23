//
//  PageShotsLanguagesSection.swift
//  Atlas
//

import SwiftUI

/// Plan's Own images for: the page's languages (the primary always on; one
/// without every caption yet can't be chosen) and the devices. The others
/// keep showing the default page's screenshots.
struct PageShotsLanguagesSection: View {
    @Bindable var flow: PageShotsFlow
    let source: PageShotsSource

    var body: some View {
        let run = flow.run
        let chosen = run?.locales ?? []
        let ready = Set(flow.readyLocales)
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text("Own images for").font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(chosen.count) of \(flow.languages.count) languages")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .accessibilityIdentifier("pages.shots.languageCount")
            }
            FlowLayout(spacing: Spacing.xxSmall, lineSpacing: Spacing.xxSmall) {
                ForEach(flow.languages, id: \.self) { locale in
                    PageShotsChip(
                        title: ProductPageChangeBuilder.localeName(locale), regionCode: ProductPageChangeBuilder.region(locale),
                        isOn: chosen.contains(locale), isEnabled: locale != run?.primaryLocale && ready.contains(locale),
                        identifier: "pages.shots.language.\(locale)"
                    ) { flow.toggle(locale: locale) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Languages"))
            HStack(spacing: Spacing.xxSmall) {
                ForEach(source.displays, id: \.self) { display in
                    PageShotsChip(
                        title: display.deviceName, isOn: run?.displays.contains(display) ?? false,
                        identifier: "pages.shots.device.\(display.rawValue)"
                    ) { flow.toggle(display: display) }
                }
            }
            .padding(.top, Spacing.xxSmall)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Devices"))
            Text(note(chosen: chosen.count, ready: ready.count))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pages.shots.languagesNote")
        }
    }

    private func note(chosen: Int, ready: Int) -> String {
        let others = flow.languages.count - chosen
        let waiting = flow.run?.plan == nil ? 0 : flow.languages.count - ready
        var text = others == 0
            ? String(localized: "Every language gets the page’s own screenshots.")
            : others == 1
            ? String(localized: "The other language keeps the default page’s screenshots.")
            : String(localized: "The other \(others) languages keep the default page’s screenshots.")
        if waiting > 0 {
            text += " " + (waiting == 1
                ? String(localized: "1 has no captions yet.")
                : String(localized: "\(waiting) have no captions yet."))
        }
        return text
    }
}
