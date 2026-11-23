//
//  OverviewListCard.swift
//  Atlas
//

import SwiftUI

/// One of the Overview's lists: a card with a title, then rows split by
/// hairlines (the prototype's `.card` with `.ovr` rows: 16 pt on top, 18 at
/// the sides, 6 under the last row).
struct OverviewListCard<Header: View, Rows: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var rows: () -> Rows

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header()
                    .padding(.bottom, 10)
                rows()
            }
            .padding(EdgeInsets(top: Spacing.large, leading: 18, bottom: 6, trailing: 18))
        }
    }
}

extension OverviewListCard where Header == OverviewListTitle {
    init(title: String, titleIdentifier: String, @ViewBuilder rows: @escaping () -> Rows) {
        header = { OverviewListTitle(title: title, identifier: titleIdentifier) }
        self.rows = rows
    }
}
