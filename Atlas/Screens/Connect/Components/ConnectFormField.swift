//
//  ConnectFormField.swift
//  Atlas
//

import SwiftUI

/// One labeled text field of the connect form, monospaced: its name, where
/// to find the value, a green check once it looks right, and a red outline
/// with its hint underneath while the value is malformed.
struct ConnectFormField: View {
    let title: LocalizedStringKey
    var hint: LocalizedStringKey = ""
    var showsHint = true
    @Binding var text: String
    let prompt: String
    var width: CGFloat?
    var looksRight = false
    let issue: CredentialsIssue?
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            ConnectFieldLabel(title: title, hint: hint, showsHint: showsHint, looksRight: looksRight, identifier: identifier)
            TextField(title, text: $text, prompt: Text(prompt))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                .frame(width: width)
                .overlay {
                    if issue != nil {
                        RoundedRectangle(cornerRadius: Radius.flag, style: .continuous)
                            .strokeBorder(Palette.errMark, lineWidth: 1.5)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier(identifier)
            if let issue {
                Label {
                    Text(issue.message)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .font(.footnote)
                .foregroundStyle(Palette.err)
                .accessibilityIdentifier("\(identifier).issue")
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        ConnectFormField(
            title: "Issuer ID", hint: "top of the page", text: .constant("69a6de7f-3c2e-47e3"), prompt: "",
            issue: .invalidIssuerID, identifier: "a"
        )
        ConnectFormField(
            title: "Key ID", hint: "next to your key", text: .constant("2X9R4HXF34"), prompt: "2X9R4HXF34",
            looksRight: true, issue: nil, identifier: "b"
        )
    }
    .padding()
    .frame(width: 480)
}
