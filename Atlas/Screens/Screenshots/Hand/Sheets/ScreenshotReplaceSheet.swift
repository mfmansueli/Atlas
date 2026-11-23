//
//  ScreenshotReplaceSheet.swift
//  Atlas
//

import SwiftUI

/// Replace Screenshot n: the screenshot now and the file that takes its
/// place, checked against the sizes the device takes (never scaled), in
/// this language or every language with its own screenshots.
struct ScreenshotReplaceSheet: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let item: ScreenshotHandPageItem
    let locale: StoreLocale

    @State private var file: ScreenshotHandChosenFile?
    @State private var scope: ScreenshotHandScope = .one
    @State private var isTargeted = false

    init(viewModel: ScreenshotsViewModel, item: ScreenshotHandPageItem, locale: StoreLocale, initialFile: ScreenshotHandChosenFile?) {
        self.viewModel = viewModel
        self.item = item
        self.locale = locale
        _file = State(initialValue: initialFile)
    }

    private var display: ScreenshotDisplayType { item.cell.key.displayType }
    private var check: ScreenshotHandFileCheck? { file.map { ScreenshotHandFileCheck($0, on: display) } }
    private var ownCount: Int { viewModel.ownLocales(on: display).count }

    var body: some View {
        ScreenshotHandSheetLayout(
            viewModel: viewModel,
            title: String(localized: "Replace Screenshot \(item.position + 1)"),
            subtitle: subtitle,
            okTitle: scope == .every ? String(localized: "Replace in \(ownCount) Languages") : String(localized: "Replace"),
            isOKDisabled: check?.fits != true
        ) {
            HStack(alignment: .center, spacing: Spacing.large) {
                ScreenshotHandCurrentImage(viewModel: viewModel, cell: item.cell)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.label3)
                    .accessibilityHidden(true)
                newImage
                checks
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScreenshotHandScopeOptions(label: String(localized: "Replace it in"), options: [
                .init(scope: .one, title: String(localized: "Only \(locale.name)"),
                      detail: String(localized: "The other languages keep their own screenshot \(item.position + 1).")),
                .init(scope: .every, title: String(localized: "Every language with its own screenshots (\(ownCount))"),
                      detail: String(localized: "The same image everywhere, so any words in it show in every language."), isDisabled: ownCount < 2),
            ], selection: $scope)
            if item.cell.image.renderJob != nil {
                ScreenshotHandNote(text: String(localized: """
                Atlas made this one from the template and its caption. Once it’s replaced, Atlas won’t redraw it when the template \
                or the caption changes. Undo Change brings the template version back.
                """))
            }
        } onOK: {
            guard let file else { return }
            viewModel.handSheet = nil
            Task { await viewModel.replaceHand(slotID: item.id, with: file, scope: scope) }
        }
        .accessibilityIdentifier("screenshots.hand.replaceSheet")
    }

    private var subtitle: String {
        let others = ScreenshotHandSizes.others(on: display).map { String(localized: " (or \($0))") } ?? ""
        return String(localized: "\(locale.name) · \(display.title) · needs \(ScreenshotHandSizes.main(on: display))\(others)")
    }

    private var tileHeight: CGFloat {
        let size = viewModel.pixelSize(for: display)
        return (96 * CGFloat(size.height) / CGFloat(max(1, size.width))).rounded()
    }

    private var newImage: some View {
        VStack(spacing: Spacing.xSmall) {
            if let file {
                ScreenshotHandChosenImage(file: file, width: 96, height: tileHeight)
            } else {
                Button(action: choose) {
                    VStack(spacing: Spacing.xxSmall) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3.weight(.semibold))
                        Text("Drop a file, or click")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 96, height: tileHeight)
                    .background(isTargeted ? Palette.accentTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                            .strokeBorder(Palette.label3, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("screenshots.hand.replace.drop")
            }
            Pill(text: String(localized: "New"), style: .accent)
                .fixedSize()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let dropped = ScreenshotHandDrop.files(from: urls).first else { return false }
            file = dropped
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private var checks: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let file, let check {
                if check.fits, let size = file.pixelSize {
                    Label("\(size.title), the size \(display.title) needs", systemImage: "checkmark")
                        .foregroundStyle(Palette.increase)
                    Label(file.fileName.lowercased().hasSuffix("png") ? "PNG, no transparency" : "JPEG", systemImage: "checkmark")
                        .foregroundStyle(Palette.increase)
                    Label(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file), systemImage: "checkmark")
                        .foregroundStyle(Palette.increase)
                } else {
                    Label(check.problem(fileName: file.fileName, on: display) ?? "", systemImage: "xmark")
                        .foregroundStyle(Palette.err)
                        .accessibilityIdentifier("screenshots.hand.replace.problem")
                    Text("Atlas never scales a screenshot for you: App Review rejects stretched ones.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            } else {
                Text("PNG or JPEG, \(ScreenshotHandSizes.all(on: display)), no transparency.")
                    .foregroundStyle(Palette.label2)
            }
            Button(file == nil ? String(localized: "Choose File…") : String(localized: "Choose Another File…"), action: choose)
                .controlSize(.regular)
                .accessibilityIdentifier("screenshots.hand.replace.choose")
        }
        .font(.callout)
    }

    private func choose() {
        if let chosen = ScreenshotHandFilePanel.chooseFiles(display: display, language: locale.name, multiple: false)?.first {
            file = chosen
        }
    }
}
