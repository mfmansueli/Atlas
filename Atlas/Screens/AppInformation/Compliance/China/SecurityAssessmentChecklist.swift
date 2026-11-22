//
//  SecurityAssessmentChecklist.swift
//  Atlas
//

import SwiftUI

/// The Security Assessment's Yes: what App Store Connect takes, both from
/// the National Internet Security Management Service Platform. They're
/// files only the person has, uploaded in App Store Connect.
struct SecurityAssessmentChecklist: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Upload in App Store Connect:")
                .font(.subheadline.weight(.semibold))
            Label {
                Text("""
                A screenshot from the National Internet Security Management Service Platform showing the app’s \
                name, your name as provider, and the assessment passed.
                """)
            } icon: {
                Image(systemName: "photo")
            }
            Label {
                Text("The Security Assessment report, with the app’s name, your name as provider, and your company’s seal.")
            } icon: {
                Image(systemName: "doc.text")
            }
        }
        .font(.subheadline)
        .foregroundStyle(Palette.label2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.compliance.securityAssessment.checklist")
    }
}
