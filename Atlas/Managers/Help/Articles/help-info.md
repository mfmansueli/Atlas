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

- **Suggested fields** include General's Games subcategories (for the primary category while it's Games, and for the secondary category while it's Games), App Review's sign-in and demo account user name, the accessibility URL, and each language's User Privacy Choices URL in App Privacy, Privacy URLs. The demo account's password is never read or suggested: you type it.
- **App Privacy's bar** accepts or dismisses the User Privacy Choices URLs suggested there, and its arrows go to the previous or next language with one. App Privacy's answers are never in it: you accept each one in the worksheet.
- **App Compliance** covers rules in some countries: trader details in the EU, the ICP filing number in China mainland, and licences.
- **Export Compliance** asks whether the app uses encryption that needs documents. When App Store Connect only has a build's answer, the page shows it as exempt encryption, marked as the build's answer: that answer can't tell exempt encryption from none at all.
- **Skip the question for every build**: once the answers are settled (you answered or confirmed them, or the build's answer stands uncontradicted), **Add It to the Project** asks Claude Code to add `ITSAppUsesNonExemptEncryption` to the app target: the `INFOPLIST_KEY_` build setting when the target generates its Info.plist, else the key in its Info.plist. Encryption that isn't exempt also names an approved declaration's code. Claude Code commits only when your project's own instructions say so, and never pushes or uploads. The card then says where it was added. It also says when Atlas read the key in the project folder, or infers it from your newest uploads arriving already answered; an answer given per build in App Store Connect looks the same, so that's marked as inferred.

> These answers are statements you make to Apple and to regulators. Atlas never accepts them for you, including with Accept All Pages.
