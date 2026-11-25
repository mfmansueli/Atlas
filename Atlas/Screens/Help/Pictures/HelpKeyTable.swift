//
//  HelpKeyTable.swift
//  Atlas
//

import SwiftUI

/// The Team Keys table in a Help picture: its header and the Atlas key's
/// row, with Download or the Key ID in the ring.
struct HelpKeyTable: View {
    enum Ring {
        case download
        case keyID
    }

    let ring: Ring

    var body: some View {
        VStack(spacing: 0) {
            row(
                name: Text(AppStoreConnectPageWords.name),
                keyID: Text(AppStoreConnectPageWords.keyID),
                access: Text(AppStoreConnectPageWords.access),
                action: Text(verbatim: "")
            )
            .fontWeight(.semibold)
            .foregroundStyle(Palette.label2)
            .background(
                Palette.fill1,
                in: UnevenRoundedRectangle(topLeadingRadius: Radius.menuRow, topTrailingRadius: Radius.menuRow, style: .continuous)
            )
            row(
                name: Text(verbatim: "Atlas"),
                keyID: Text(verbatim: HelpDrawing.sampleKeyID)
                    .atlasTextStyle(.footnote)
                    .fontDesign(.monospaced)
                    .helpPictureRing(isOn: ring == .keyID),
                access: Text(AppStoreConnectPageWords.admin),
                action: Text(AppStoreConnectPageWords.download)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.accentText)
                    .helpPictureRing(isOn: ring == .download)
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous)
                .strokeBorder(Palette.separator, lineWidth: 0.5)
        }
        .padding(.horizontal, Spacing.medium)
    }

    private func row(name: some View, keyID: some View, access: some View, action: some View) -> some View {
        HStack(spacing: Spacing.small) {
            name.frame(width: Metrics.helpPictureNameColumn, alignment: .leading)
            keyID.frame(width: Metrics.helpPictureKeyIDColumn, alignment: .leading)
            access.frame(width: Metrics.helpPictureAccessColumn, alignment: .leading)
            action
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xSmall)
        .padding(.horizontal, Spacing.medium)
    }
}
