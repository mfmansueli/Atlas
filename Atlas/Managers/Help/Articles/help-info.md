---
id: info
group: listing
title: App Information, privacy and compliance
summary: The answers Apple asks for once per app: category, age rating, accessibility, App Privacy and App Compliance.
keywords: app information, category, games subcategory, sign-in, demo account, privacy choices, accessibility url, age rating, accessibility, app privacy, privacy labels, nutrition labels, compliance, trader, dsa, icp, china, licence, license, export compliance, encryption, ITSAppUsesNonExemptEncryption, info.plist
showMe: section:appInformation
related: suggest
---
Each page shows its status: up to date, suggestions waiting, or needs you.

An assistant can read your project and suggest answers, with the evidence beside each one.

- **Suggested fields**: Games subcategories in General, App Review's sign-in and demo user name, the accessibility URL, and each language's User Privacy Choices URL. The demo password is never read or suggested; you type it.
- **App Privacy's bar** accepts or dismisses suggested User Privacy Choices URLs and jumps between languages with one. App Privacy's answers are never in it: you accept each in the worksheet.
- **App Compliance** covers rules in some countries: trader details in the EU, the ICP filing number in China mainland, and licences.
- **Export Compliance** asks whether the app uses encryption that needs documents. If App Store Connect has only a build's answer, the page shows exempt encryption, marked as the build's answer: it can't tell exempt from none.
- **Skip the question for every build**: once the answers are settled (answered, confirmed or uncontradicted), **Add It to the Project** asks Claude Code to add `ITSAppUsesNonExemptEncryption` to the app target, as the `INFOPLIST_KEY_` build setting or in Info.plist. Non-exempt encryption also needs an approved declaration's code. Claude Code commits only if your project's instructions say so, and never pushes or uploads. The card shows where the key is, or marks it inferred when your newest uploads arrive already answered.

> These answers are statements you make to Apple and to regulators. Atlas never accepts them for you, including with Accept All Pages.
