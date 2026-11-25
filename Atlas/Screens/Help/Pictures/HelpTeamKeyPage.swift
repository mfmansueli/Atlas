//
//  HelpTeamKeyPage.swift
//  Atlas
//

import SwiftUI

/// Step 2's picture: Integrations' App Store Connect API page on Team
/// Keys, with + and Generate API Key's Access (Admin) in the ring.
struct HelpTeamKeyPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HelpPageNav()
            HStack(alignment: .top, spacing: Spacing.small) {
                side
                VStack(alignment: .leading, spacing: Spacing.small) {
                    tabs
                    form
                }
            }
            .padding(.horizontal, Spacing.medium)
        }
    }

    private var side: some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text(AppStoreConnectPageWords.appStoreConnectAPI)
                .fontWeight(.semibold)
                .sideRow()
                .background(Palette.fill2, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
            Text(AppStoreConnectPageWords.inAppPurchase)
                .foregroundStyle(Palette.label2)
                .sideRow()
        }
        .frame(width: Metrics.helpPictureSideWidth)
    }

    private var tabs: some View {
        HStack(spacing: Spacing.small) {
            Text(AppStoreConnectPageWords.teamKeys)
                .fontWeight(.semibold)
                .padding(.bottom, Spacing.tiny)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.accent).frame(height: Metrics.helpPictureTabUnderline)
                }
            Text(AppStoreConnectPageWords.individualKeys)
                .foregroundStyle(Palette.label2)
                .padding(.bottom, Spacing.tiny)
            Spacer(minLength: 0)
            Image(systemName: "plus")
                .atlasTextStyle(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: Metrics.helpPictureAddButton, height: Metrics.helpPictureAddButton)
                .background(Palette.accent, in: Circle())
                .helpPictureRing(.button)
                .padding(.trailing, Spacing.medium)
        }
    }

    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.small, verticalSpacing: Spacing.xSmall) {
            GridRow {
                Text(AppStoreConnectPageWords.generateAPIKey)
                    .fontWeight(.semibold)
                    .gridCellColumns(2)
            }
            GridRow {
                Text(AppStoreConnectPageWords.name)
                    .foregroundStyle(Palette.label2)
                field(Text(verbatim: "Atlas"))
            }
            GridRow {
                Text(AppStoreConnectPageWords.access)
                    .foregroundStyle(Palette.label2)
                field(HStack(spacing: Spacing.xxSmall) {
                    Text(AppStoreConnectPageWords.admin)
                    Image(systemName: "chevron.down")
                        .atlasTextStyle(.footnote)
                        .foregroundStyle(Palette.label2)
                })
                .helpPictureRing(.field)
            }
            GridRow {
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
                Text(AppStoreConnectPageWords.generate)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, Spacing.tiny)
                    .background(Palette.accent, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(Spacing.small)
        .frame(width: Metrics.helpPictureFormWidth, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .strokeBorder(Palette.separator, lineWidth: 0.5)
        }
        .depth(.popover)
    }

    private func field(_ content: some View) -> some View {
        content
            .padding(.horizontal, Spacing.xSmall)
            .padding(.vertical, Spacing.tiny)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                    .strokeBorder(Palette.separator2, lineWidth: 0.5)
            }
    }
}

private extension View {
    /// A row of Integrations' side list.
    func sideRow() -> some View {
        lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.xSmall)
            .padding(.vertical, Spacing.tiny)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
