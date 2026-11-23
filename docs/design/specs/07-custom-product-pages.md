ATLAS · CUSTOM PRODUCT PAGES · NOVEMBER 2026

# A page for each audience, made the way the rest of Atlas works

Product Pages lists every custom product page beside the default one, edits each in every language, makes its screenshots with Autopilot, takes suggestions from your assistant, and sends it through Review & Push and App Review.

**On the canvas** (page *Custom Product Pages*): boards **50–55**, static and full size (1200 × 780, with taller tiles where the editor is shown whole). 50 the list · 51 New Page and the editor · 52 screenshots for a page · 53 the assistant · 54 Review & Push and App Review · 55 hiding, deleting and the ways in. Everything is also in the main prototype: Product Pages in the sidebar.

## What Apple allows, and what the design does with it

| Apple | In Atlas |
| --- | --- |
| Up to 70 pages for each app | A counter in the header (“6 of 70”). At 70, New Page and Suggest Pages are off and a banner says that hidden and rejected pages count. |
| A reference name, a link, a visibility switch | The name is the title of the page in Atlas. Link with Copy and Open. Visible is a switch, off and disabled until the page is approved. |
| Per language: screenshots, App Previews, promotional text (170) | The language bar, then three cards. A language with nothing of its own says it shows the default page’s. |
| An optional deep link | One field with a check under it: opens in Lumen, isn’t a complete link, or optional. |
| Keywords per language, only from the last approved version’s keywords | Chips to tick, never a text field. A chip another page uses carries that page’s name. |
| Starts empty, from a version’s default page, or as a copy of another page | Three choices in New Page. |
| Reviewed by itself; editing an approved page makes a new version | Status pills, a banner for each state, and the approved version beside the new one while you edit. |
| Analytics by page | The list shows impressions → views → downloads and the download rate against the default page, from the same numbers as Analytics. |

## Where it lives

- **Product Pages** is its own section in the sidebar, in **Store Listing**, after Screenshots. It joins text, images, keywords and a link, so it fits no existing section.
- Its purple count is suggested pages plus languages with a suggested text.
- **Overview** has a Product Pages card: how many pages, how many are visible, the best one, and Open.
- **Analytics → Break It Down → Product Page**: a custom page’s row has **Open Page**.

### Shortcuts

The shortcuts follow the sidebar’s order, so one more section moves four of them.

| Section | Before | Now |
| --- | --- | --- |
| Overview · Store Page · Screenshots | ⌘1 · ⌘2 · ⌘3 | the same |
| **Product Pages** | — | **⌘4** |
| In-App Events | ⌘4 | ⌘5 |
| App Information | ⌘5 | ⌘6 |
| Pricing | ⌘6 | ⌘7 |
| Reviews | ⌘7 | ⌘8 |
| Analytics | ⌘8 | ⌘9 |

The sidebar, the section menu, Atlas Help’s shortcuts article and the READMEs for Release and Analytics were updated to match.

## The screens

### 50 · The list

- The **default product page** is the first row, tinted, marked as the reference.
- Each page: name, languages, keywords and where its link is used; status, and Visible or Hidden; the funnel; the download rate with “▲ 2.1 pt above default”, “about the same”, or “96 views is too few to compare”; Copy Link.
- A page with a new version in review shows both pills.
- Pages that have no numbers say why: not approved yet, or hidden.
- Empty: what a page is for in three lines, **Create the First Page…** and **Ask Claude Code for Ideas**.
- Below 900 pt of width each page becomes two lines and the column headings go away. Nothing is cut.

### 51 · New Page and the editor

- **New Page:** name, start from (default page of 1.4, a copy, empty), who it is for and what it should do (a note for the assistant, not sent to Apple), and which languages get their own content.
- **Editor header:** back, name, status, changes not pushed, Discard…, Delete…, **Push and Submit…**
- **Link and visibility** on the left, **deep link** on the right, in one card.
- **Language bar** as in In-App Events: a purple dot for a suggestion, a small dot for own content, Accept All Languages.
- **Promotional Text** with its count; **Search Keywords** as chips; **Screenshots and App Previews** per device, Same as Default or Own.
- **On the App Store:** the default page and this page side by side in the chosen language. What differs is outlined.

### 52 · Screenshots for a page

**Make Screenshots for This Page…** opens Autopilot with the page’s note as its angle. Three steps instead of six, because the app, the devices and the template are already known.

| Step | What the person sees |
| --- | --- |
| Plan | The angle (editable), the same five screens in another order with other captions, the look (same template, another, or a new look from Claude Design), which languages and devices get their own images, and who does what for how long. |
| Making | One bar, one sentence, and image tiles that load one by one. Hide · Keeps Going. |
| Result | The default page’s set above the new one, four checks, and where to use it. Use These Screenshots puts them in Review & Push. |

### 53 · The assistant

- Claude Code suggests **whole pages** through MCP: who it is for, keywords, promotional text in every language, the order of the screens and their captions, a deep link.
- Each suggestion has its **reason and where the evidence comes from**, in a pill: a product page test in Analytics, the reviews, version 1.3’s keywords.
- **Suggest Pages** and **Ask Claude Code for Ideas** send the request to the assistant button in the toolbar, which shows it is working (board 56).
- They arrive like every other suggestion: a count in the sidebar, Dismiss and Accept on each, **Accept All**. Accepting makes a draft page.
- Inside a page, a suggested promotional text is the app’s usual purple block: Now, Suggested, Dismiss, Use and Edit, Accept.
- **A suggestion Atlas stopped** is shown, with the offending words underlined and the reason, as **Not offered**. It has no Accept: only See the Rules and Ask for Another.

### 54 · Review & Push, and App Review

- **Push and Submit…** opens Review & Push for the page: page, version, promotional text, keywords, screenshots and App Preview, each on a line, sent in one push.
- While pushing, each line is ticked as it lands.
- If some parts are not accepted, they are **grouped by reason**, each with its own fix, and **Retry What Failed**. What landed is not sent twice.
- Then **Submit for Review…**: what goes to Apple, four checks, and “Make the page visible when it’s approved”.
- Waiting for Review and In Review lock the page. Approved offers Edit…, which starts version 2 and shows it beside version 1. Rejected says where to read Apple’s message.

### 55 · Hiding, deleting, and the ways in

- **Hide** and **Delete** ask first, and the sentence says what happens to the link and to searches.
- **Discard** says what is undone and what stays.
- The Overview card and the Analytics row.

## Rules

- **Sending is always the person’s.** An assistant suggests and prepares. It can’t push, submit, or make a page visible. The Submit sheet says so.
- **Two steps, said as two:** pushing saves the page in App Store Connect; submitting sends it to App Review. Neither puts it on the App Store. Every sheet repeats which step you are on.
- **Promotional text follows the rules Atlas already applies:** no price, “free”, discount or other platform. A text that breaks them can’t be accepted.
- **Nothing is invented.** If the API doesn’t give the reviewer’s message, Atlas says that. If a page has too few visits, Atlas says that instead of a comparison.
- **The default page never changes from here.** Autopilot for a page makes a set for that page only, and says so three times.
- **Left-to-right things stay left to right** in Arabic: links, deep links, the screenshot strip.

## Components reused

| Component | From | Used for |
| --- | --- | --- |
| Sidebar item, count badge, section header | Navigation | Product Pages ⌘4 |
| Language bar with chips and Accept All Languages | In-App Events | The editor |
| Suggestion block: Suggested, source, Now / Suggested, Dismiss · Use and Edit · Accept | Store Page | Promotional text |
| Suggestion group with Accept All and its count | Store Page, Pricing | Suggested pages |
| Text field with counter | Store Page, In-App Events | Promotional text (170) |
| Screenshot thumbnails, drawn by the template engine | Screenshots | The strip, the preview, the Autopilot sheet |
| Steps in a sheet, progress bar, Hide · Keeps Going | Screenshot Autopilot | Screenshots for a page |
| Loading tiles | Screenshots | Autopilot’s Making step, and the list while it loads |
| Review & Push rows, check marks, failure boxes | Review & Push | Pushing a page |
| Submit sheet: what goes to Apple, checks, a switch | Submit for Review | Submitting a page |
| Status pills and banners | Version card, In-App Events | The five review states |
| Toast with Undo | Everywhere | Accept, dismiss, hide |

### New, and kept small

- **Keyword chips:** chosen (blue, ticked), free, and used by another page (with that page’s name).
- **Funnel cell:** three numbers with arrows, and the rate under it.
- **Two-page preview:** default and this page, side by side.
- **Version compare:** approved on the left, new on the right, changes highlighted.
- **“Not offered” block:** the suggestion block in the warning color, without Accept.

## Decisions where the brief said nothing

1. **“Dismiss”, not “Reject”.** The app already says Dismiss, Use and Edit, Accept. Reject is kept for App Review.
2. **28 days, not 30.** Analytics offers 7, 28 and 90 days. The list uses 28 so its numbers are the same as Analytics’, to the digit.
3. **Download rate is the comparison.** Downloads out of page views, against the default page. Under 200 page views Atlas says “too few to compare”. The threshold is mine.
4. **A new page is a draft in Atlas** until the first push. Apple makes the link then, so the editor says so instead of showing an empty field.
5. **One button, Push and Submit…**, for the two steps, with the second step only offered after the first succeeds.
6. **Visible is decided when submitting** (“Make the page visible when it’s approved”, on by default) and is a plain switch after approval.
7. **A keyword leads to one page.** Ticking one that another page uses asks before moving it.
8. **Every page exists in every language.** A language either has its own content or shows the default page’s. New Page asks which languages start with their own.
9. **Three Autopilot steps for a page**, not six.
10. **Suggested pages need evidence.** A suggestion without a source Atlas can show (Analytics, reviews, the approved keywords) isn’t listed.
11. **Free and Pro** (not drawn): making, editing, pushing and submitting pages is free. Suggest Pages, Accept All and Autopilot for a page are Pro, like their counterparts.
12. **Hebrew:** Lumen’s 12 languages include Arabic and not Hebrew, so the right-to-left boards are in Arabic. Hebrew mirrors the same way.
13. **Delete is in the editor’s header**, not in the list, so it is never one click from a row.

## App Store Connect API

| Part | Resources |
| --- | --- |
| Pages | `appCustomProductPages` (name, link, visible) |
| Versions and review state | `appCustomProductPageVersions` (state, deep link) |
| Languages | `appCustomProductPageLocalizations` (promotional text, keywords) |
| Images and video | `appScreenshotSets`, `appPreviewSets` under each localization |
| Review | `reviewSubmissions` and `reviewSubmissionItems`, the same as versions and events |
| Numbers | The analytics reports Atlas already reads, by product page |

**To confirm against the API before building.** I wrote these from your brief and from memory, and did not test them: the exact resource and field names above; whether one keyword may belong to two pages (the design assumes not); what a hidden or deleted page’s link opens (the design says the default page); which key roles may edit pages (the design says Admin, App Manager, Marketing); and whether the reviewer’s message is ever in the API (the design assumes not). Each is one sentence or one rule in the design, so a different answer is a small change.

## Covered

Light and dark · Increase Contrast, light and dark · Arabic, right to left · German at 158 of 170 characters · the minimum window, 860 × 560, with the sidebar hidden, for the list, the editor, two sheets and Arabic (a sheet taller than the window scrolls its body and keeps its buttons in view) · loading · offline · a key without permission · no approved version · 70 of 70 · a language with nothing of its own · a deep link that doesn’t open.

### Not drawn

- The Free plan’s paywall for Suggest Pages and Autopilot for a page.
- Choose Files… for screenshots, and its size check.
- The menu behind ⋯ in the minimum window (Discard…, Delete…).
- Notifications for a page’s review result. They follow “App Review changes a version’s or an event’s status” in Settings.

## Prototype scenes

`cp` `cp-sug` `cp-nosug` `cp-empty` `cp-limit` `cp-loading` `cp-offline` `cp-norole` `cp-new` `cp-new-copy` `cp-edit` `cp-edit-de` `cp-edit-ar` `cp-edit-fr` `cp-edit-ipad` `cp-edit-refused` `cp-edit-deeplink` `cp-edit-noversion` `cp-shots-plan` `cp-shots-run` `cp-shots-result` `cp-push` `cp-pushing` `cp-push-partial` `cp-push-done` `cp-submit` `cp-waiting` `cp-inreview` `cp-approved` `cp-hidden` `cp-rejected` `cp-liveedit` `cp-hide` `cp-delete` `cp-discard` `cp-kwmove` `cp-s` `cp-edit-s` `cp-edit-ar-s` `cp-shots-s` `cp-push-s`
