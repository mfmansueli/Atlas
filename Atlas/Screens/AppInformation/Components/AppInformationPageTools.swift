//
//  AppInformationPageTools.swift
//  Atlas
//

import SwiftUI

/// The line over a page's fields, under the page strip (board 88): where
/// the page shows on the App Store, for pages whose fields don't each say
/// it, and the page's own controls on the right (a status, a version menu,
/// a link). The page's name is its open card; its sentence is at the top.
struct AppInformationPageTools<Trailing: View>: View {
    var whereShown: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.small) {
            if let whereShown {
                Label {
                    Text(whereShown)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("appInformation.whereShown")
            }
            Spacer(minLength: Spacing.small)
            trailing()
        }
    }
}

extension AppInformationPageTools where Trailing == EmptyView {
    init(whereShown: String?) {
        self.init(whereShown: whereShown) { EmptyView() }
    }
}

#Preview {
    AppInformationPageTools(whereShown: "On the App Store: the age under the name, such as 4+.") {
        Pill(text: "Complete")
    }
    .padding()
    .frame(width: 600)
}
