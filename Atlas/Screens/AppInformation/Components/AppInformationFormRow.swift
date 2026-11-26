//
//  AppInformationFormRow.swift
//  Atlas
//

import SwiftUI

/// One row of an `AppInformationFormSection`: a label (with an optional
/// second line, and the line that says where the field shows) on the left,
/// its control on the right.
struct AppInformationFormRow<Control: View>: View {
    let label: String
    var detail: String?
    /// "In the Information section of the page", "Only Apple sees this"
    /// (`AppInformationFieldPlacement`, board 88).
    var whereShown: String?
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let whereShown {
                    Text(whereShown)
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.medium)
            control()
        }
        .padding(.horizontal, Spacing.medium + 2)
        .padding(.vertical, Spacing.small + 1)
        .frame(minHeight: 40)
    }
}

#Preview {
    AppInformationFormRow(label: "Copyright", whereShown: "In the Information section of the page") {
        TextField("Copyright", text: .constant("© 2026 Northpier Studio"))
            .labelsHidden()
            .frame(width: 260)
    }
    .frame(width: 600)
}
