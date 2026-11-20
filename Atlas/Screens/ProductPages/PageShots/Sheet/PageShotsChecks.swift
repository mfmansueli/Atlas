//
//  PageShotsChecks.swift
//  Atlas
//

import SwiftUI

/// Result's four checks: the sizes Apple needs, the captions fit, right to
/// left where a language reads that way, and the default page untouched.
struct PageShotsChecks: View {
    let flow: PageShotsFlow

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Checks").font(.headline)
            ForEach(checks, id: \.title) { check in
                HStack(alignment: .top, spacing: Spacing.small) {
                    Image(systemName: check.isOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(check.isOK ? Palette.positive : Palette.warningMark)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(check.title).font(.callout)
                        Text(check.detail)
                            .font(.caption)
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("pages.shots.check.\(check.id)")
            }
        }
    }

    private struct Check {
        var id: String
        var title: String
        var detail: String
        var isOK: Bool
    }

    private var checks: [Check] {
        guard let run = flow.run else { return [] }
        let sizes = run.useDisplays.map(\.title).formatted(.list(type: .and))
        let used = run.useLocales.map(ProductPageChangeBuilder.localeName)
        var checks = [
            Check(
                id: "sizes", title: String(localized: "Every size Apple needs"),
                detail: sizes.isEmpty ? String(localized: "Choose a device below.") : sizes, isOK: !sizes.isEmpty
            ),
        ]
        let overflowing = flow.overflowing
        if overflowing.isEmpty {
            checks.append(Check(
                id: "fit", title: String(localized: "Captions fit on every device"),
                detail: String(localized: "In \(used.formatted(.list(type: .and)))."), isOK: true
            ))
        } else {
            let places = Set(overflowing.map { ProductPageChangeBuilder.localeName($0.locale) }).sorted().formatted(.list(type: .and))
            checks.append(Check(
                id: "fit", title: String(localized: "A caption doesn’t fit"),
                detail: String(localized: "In \(places): it’s drawn smaller than the template allows. Ask for a shorter one."), isOK: false
            ))
        }
        let rightToLeft = run.useLocales.filter { StoreLocaleCatalog.locale(code: $0)?.isRTL == true }
        if !rightToLeft.isEmpty {
            checks.append(Check(
                id: "rtl", title: String(localized: "\(rightToLeft.map(ProductPageChangeBuilder.localeName).formatted(.list(type: .and))) runs right to left"),
                detail: String(localized: "Captions and the template, as on the default page."), isOK: true
            ))
        }
        checks.append(Check(
            id: "default", title: String(localized: "The default page doesn’t change"),
            detail: String(localized: "Its screenshots, captions and template stay as they are."), isOK: true
        ))
        return checks
    }
}
