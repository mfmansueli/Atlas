//
//  ErrorCopyMessage.swift
//  Atlas
//

import SwiftUI

/// An Apple error as the error template shows it: what happened and what
/// to do, in the error tint, with a "Details" button that shows Apple's
/// own text in a popover. Apple's text is never the message.
struct ErrorCopyMessage: View {
    let copy: AppleErrorCopy
    @State private var showsDetails = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            InlineMessage.error(copy.summary)
            if let details = copy.details {
                Button(String(localized: "Details", comment: "kind:button")) {
                    showsDetails.toggle()
                }
                .buttonStyle(.link)
                .font(.callout)
                .popover(isPresented: $showsDetails, arrowEdge: .bottom) {
                    Text(details)
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 360, alignment: .leading)
                        .padding(Spacing.medium)
                }
                .accessibilityHint(Text(String(localized: "Shows Apple’s own message.", comment: "kind:accessibility-label")))
            }
        }
    }
}

#Preview {
    ErrorCopyMessage(copy: AppleErrorCopy(
        "Prices didn’t load.",
        error: AppStoreConnectError.server(statusCode: 503, detail: nil)
    ))
    .padding()
}
