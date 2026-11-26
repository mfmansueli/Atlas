//
//  PageCardStrip.swift
//  Atlas
//

import SwiftUI

/// A strip of page cards that scrolls sideways (board 88; README-DS §16):
/// App Information's seven pages, Analytics' six views. It fades out on
/// the right with a round arrow that scrolls on, and scrolls to the open
/// card when the selection changes (without moving when the screen opens).
struct PageCardStrip<ID: Hashable>: View {
    let items: [PageCardItem<ID>]
    @Binding var selection: ID
    /// VoiceOver's name for the strip: "App Information pages".
    let label: String
    /// The accessibility identifier; each card adds ".<identifier>".
    var identifier: String = "pageStrip"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Room left to scroll on the right.
    @State private var hasMore = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xSmall) {
                    ForEach(items) { item in
                        if let group = item.groupTitle {
                            groupLabel(group)
                        }
                        PageCardView(item: item, isSelected: item.id == selection) {
                            selection = item.id
                        }
                        .id(item.id)
                        .accessibilityIdentifier("\(identifier).\(item.identifier ?? String(describing: item.id))")
                    }
                }
                .padding(.vertical, Spacing.tiny)
                .padding(.leading, Spacing.tiny)
                .padding(.trailing, hasMore ? Metrics.pageCardFade : Spacing.tiny)
            }
            .scrollIndicators(.never)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.width - geometry.contentOffset.x - geometry.containerSize.width > 1
            } action: { _, more in
                hasMore = more
            }
            .mask {
                HStack(spacing: 0) {
                    Rectangle()
                    if hasMore {
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: Metrics.pageCardFade)
                    }
                }
            }
            .overlay(alignment: .trailing) {
                if hasMore, let last = items.last {
                    Button {
                        scroll(proxy, to: last.id, anchor: .trailing)
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                            .frame(width: Metrics.pageCardScrollButton, height: Metrics.pageCardScrollButton)
                            .background(Palette.raised, in: Circle())
                            .depth(.card)
                    }
                    .buttonStyle(.plain)
                    .help(Text("Show More Pages", comment: "kind:tooltip · scrolls a strip of page cards"))
                    .accessibilityLabel(Text("Show More Pages", comment: "kind:button · scrolls a strip of page cards"))
                    .accessibilityIdentifier("\(identifier).more")
                }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, new in scroll(proxy, to: new, anchor: .center) }
        }
        .frame(height: Metrics.pageCardHeight + 2 * Spacing.tiny)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }

    private func groupLabel(_ title: String) -> some View {
        HStack(spacing: Spacing.xxSmall) {
            Divider()
                .frame(height: Metrics.pageCardHeight - 2 * Spacing.medium)
            Image(systemName: "eye.slash")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(title)
                .atlasTextStyle(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundStyle(Palette.label2)
        .padding(.horizontal, Spacing.xxSmall)
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: ID, anchor: UnitPoint) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: anchor)
        } else {
            withAnimation(MotionTiming.base.animation) { proxy.scrollTo(id, anchor: anchor) }
        }
    }
}
