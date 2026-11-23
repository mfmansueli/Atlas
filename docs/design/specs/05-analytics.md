ATLAS · ANALYTICS · NOVEMBER 2026

# Analytics: what to edit next

Analytics follows one app from impression to paid subscriber, shows where it’s worse than its own history, and sends you to the section where the fix is made. Every number leads to an action or is left out.

**Navigation update, November 16.** The sections moved from the toolbar to the sidebar, grouped as Overview · Store Listing · After Release, with the app list in a menu at the top and the version’s status at the bottom (page *Proposta · Navegação*, boards 41–43). Where this README says “tab bar” or “toolbar” for sections, read “sidebar”. Every board on the canvas already shows the new navigation.

**More data, November 22.** Retention Messaging, subscribers by page and campaign, offers, billing, crashes, deletions, sessions, web preview and widgets are designed on boards 59–62, with their own README (“Analytics: new data from Apple”). It replaces the lines below that say sales aren’t linked to pages and that usage data isn’t used.

**On the canvas** (page *Analytics*): **Prototype — Analytics** starts at setup. Press Play, then Ask Apple for Reports → the prototype skip → the funnel → Break It Down → Germany → Open Store Page in German. Boards **29–37** show every part and state, in light, with dark for the funnel and the breakdown, and at the minimum window of 860 × 560. Analytics is built into the redesign prototype, as its sixth section.

## Boards

| Board | Part | States |
| --- | --- | --- |
| 29 | Where it lives | Sidebar with Analytics ⌘9, the Overview card, the minimum window |
| 30 | Setup | Not turned on · asked, waiting · key can’t ask · vendor number missing · adding it · key can’t read sales · partly ready, both ways |
| 31 | The funnel | 28 days (light, dark) · 7 days · 90 days with another step charted · loading · data older than expected · almost no traffic · no subscription · brand-new app · 860 × 560 |
| 32 | Break it down | Territory (light, dark) · inspector (light, dark) · Brazil · language · source · device · product page · 860 × 560 |
| 33 | What to try next | Findings · suggestion waiting in Review & Push · acted on, with result · dismissed · no findings yet · the jump to the fix |
| 34 | After a change | Finished result · still measuring · too few to tell · a price change, which links to Pricing → Results |
| 35 | Subscriptions | The view · the jump to Pricing for Brazil · Retention, where the first-renewal finding leads |
| 36 | Overview card and sidebar | The card (light, dark) · the quiet sidebar |
| 37 | Settings | Settings · stopping reports for one app · vendor number missing |

## Decisions where the brief was silent

- **Analytics is ⌘8, under After Release in the sidebar.** Shortcuts follow the sidebar order, ⌘1 to ⌘9. Its count is **gray** and counts new findings; purple stays reserved for suggestions to accept. Reading a finding clears the count.
- **The sidebar shows nothing new.** A finding that sends a suggestion already raises the app’s purple count, which is enough. Selecting an app in the sidebar while in Analytics switches Analytics to that app.
- **Five views inside Analytics:** Funnel, Break It Down, What to Try, After Changes, Subscriptions (hidden for apps without subscriptions). The period (7, 28, 90 days) applies to all of them.
- **How sure, everywhere the same way.** A rate is shown with a 90% range (Wilson interval), and a three-bar meter: three bars when the range is within ±12% of the rate, two within ±30%, one otherwise. “Better” or “worse” than the app’s average only when the whole range sits above or below it; otherwise “about the same” (≈).
- **Too few to tell** when the step before has fewer than 30, or the step itself fewer than 3. Then the rate is replaced by the counts, “1 of 40”, in the tertiary color, with no ▲▼. Changes between two periods also need at least 100 and 5 on both sides, and use a two-proportion test: “sure” beyond 99%, “fairly sure” beyond 90%, “about the same” otherwise.
- **Only “worse” has a color.** ▼ and “lower” use the warning color. ▲ “better” stays in the label color, like “Better” in Pricing → Results, so color still means “look here”.
- **Territory view is a ranked table, not a map.** At 860 pt a world map makes 160 small territories invisible and can’t show a range or “too few”. The table sorts by any column.
- **With the inspector open, the counts behind the rates move into it.** The table keeps page views, the three rates and proceeds.
- **Language is derived.** Apple reports by territory. A language row adds up the territories whose App Store shows that page; the footer says so.
- **Request both an ongoing report and a one-time snapshot** when asking Apple, so the funnel can compare periods as soon as the first report lands.
- **Proceeds are after Apple’s commission and taxes**, in the team’s currency, like Pricing → Results.
- **The verdict words match Pricing → Results:** Better, Worse, About the same, Too few to tell. Pricing currently says “Too little data”; it should say “Too few to tell”.
- **Findings jump with context.** The destination shows a “From Analytics” bar with the finding and Back to Analytics.
- **At the minimum window**, the app title, the Review & Push label (the count stays) and the Assistant button fold away; section tabs tighten. The funnel keeps five steps; the breakdown inspector narrows to 250.

## The data, and its limits

- **App Store engagement and commerce reports** (Analytics Reports API): impressions, product page views, first-time downloads and redownloads by day, territory, source, page type and device. Asking for them needs an **Admin** key, once per app; after that, Admin, Finance or Sales keys can read them. The first ongoing report arrives about 24 to 48 hours later. A day’s data is complete two days later, so “Data through” is always 1 to 2 days behind and there is never a “today”.
- **Privacy threshold:** Apple omits rows with fewer than five users or devices and adds noise to metrics. Totals include hidden rows, so rows add up to less. Said once, in the breakdown footer.
- **Usage** (sessions, installs, crashes) only covers people who share diagnostics. If shown later, it is labelled “a sample of people who share analytics”. This design doesn’t use it: it doesn’t lead to an edit in Atlas.
- **Sales and Trends** (vendor number, Admin, Finance or Sales key): trial starts, conversions, renewals, cancellations with Apple’s reasons (Canceled, Billing Issue, Price Increase Consent, Price Increase Notice, Removed From Sale, Other), refunds, active subscribers, proceeds.
- **Not linked by Apple:** sales to sources or product pages. Those columns show “—” and the footer says why.
- **To check:** Apple’s commerce category in the Analytics Reports API also lists subscription event and state reports. If they carry what this design needs, sales could come without a vendor number. The design keeps the vendor number, as the brief asks, until that’s confirmed.

## Components

### Reused

- Section header with icon tile, segmented controls, buttons, cards, boxes and rows, banners (neutral and warning), pills, count pills, flags, the inspector, the sheet, the toast.
- **Suggestion source marks** (AL Built-in, CC Claude Code) on findings, plus one new mark for Apple’s product page test result.
- **Pricing → Results** layout for After Changes: three cards, before → after, the verdict pill, the seasonality footnote.
- The purple suggestion state inside a finding (“waiting in Screenshots”) and the blue Review & Push state.

### New

| Component | Spec |
| --- | --- |
| Funnel strip | Five step tiles (count 19/700, tabular; change vs before 11 pt) joined by rate buttons (104 wide; label 11; rate 15/700 with the meter; change and verdict). The selected rate has the accent ring and drives the chart. |
| Confidence meter | Three bars, 2.5 × 4 / 6.5 / 9 pt, 1.5 gap; filled bars in label-2, empty in sep-2. Hidden when too few. |
| Verdict mark | ▲ label, ▼ warning, ≈ label-3; 9 pt. Always with a text equivalent in the tooltip and VoiceOver label. |
| Timeline chart | 170 pt high; previous period shaded fill-1; line accent 1.8; 6-month average dashed label-3; pushes as 1 pt rules with a label chip that opens the change’s result. |
| Callout | The biggest loss in words; warning tint when it’s a loss, neutral otherwise; up to two buttons. |
| Finding card | Source mark, area pill, New, “how sure” pill; title 14/600; why; number chips; how-sure line; state line; Dismiss, a secondary action, one primary action. |
| From Analytics bar | Fill-1 bar at the top of the destination section, with the finding and Back to Analytics. |
| Neutral count pill | The count pill in fill-3 with label text, for new findings. |

Tokens: the existing ones only. Analytics’ section color is indigo (#5856D6) on the icon tile; no new semantic colors.

## Copy for empty and error states

| State | Copy |
| --- | --- |
| Not turned on | See where people drop off · Analytics follows {app} from the first time someone sees it on the App Store to a paid subscription… · **Ask Apple for Reports** · “This asks App Store Connect to start making analytics reports for {app}. It’s the only thing Analytics changes there: your app and store page stay as they are.” |
| Waiting | Apple is preparing the reports · They usually arrive in 1 to 2 days. Asked on {date}, so expect them around {date+2}. Atlas checks every morning and lets you know when they’re here. |
| Key can’t ask | Only an Admin key can ask Apple for reports · Atlas uses key {id}, which has the App Manager role… · Use Another Key… · Open Users and Access |
| Vendor number missing (on the funnel) | Trial and paid steps: “Needs your vendor number” · Add Vendor Number… · banner: “Store-page numbers work without a vendor number. Trials, paid starts and proceeds need it.” |
| Key can’t read sales | “Your key can’t read sales” · How to Fix… · banner: “Your key ({id}) has the App Manager role, which can’t read sales. Keys with the Admin, Finance or Sales role can.” |
| Partly ready | “Sales arrive with Apple’s next report” / “Waiting for Apple · asked Nov 10”; chart: “This step arrives with Apple’s analytics reports, asked for on Nov 10.” |
| Loading | Downloading Apple’s reports for {app} · The first download includes earlier data, so it takes a minute. |
| Data older than expected | Apple’s reports are usually 1 to 2 days behind. These are {n} days behind: the newest data is from {date}. Last checked today at {time}. · Check Again |
| Almost no traffic | Too few to tell · {app} had {n} page views and {n} downloads in {period}. Rates this small move by chance, so they’re shown as counts… |
| No subscription | {app} is paid up front, so the funnel ends at downloads. |
| Brand-new app | {app} has {n} days of data · Comparisons start after a full period… |
| No findings yet | Findings need a full 28 days to compare. {app} has {n} days; the first ones come around {date}. |
| Nothing open | Nothing open. New findings appear when Apple’s next reports change something. |
| Dismissed | A dismissed finding comes back only if its numbers change a lot. |
| Change still measuring | Day {n} of 28 · final on {date}. An early read. The result is final on {date}, after 28 days; early numbers often move. |
| Change too few to tell | {territory} had about {n} impressions in each period. {a} and {b} page views are too few to tell a real change from chance. |
| Stop asking | Apple stops making new reports for {app} from tomorrow. What’s already downloaded stays on this Mac. To start again, ask again and wait 1 to 2 days. |

## Findings

- **Built-in rules** (AL) run after each download: a step worse than the app’s own history; a territory or language worse than the average on a step, with its store page, screenshots and price as the likely cause; trial → paid far below average with price against purchasing power; cancellations clustered near the first renewal with no retention message; a product page test with Apple’s confidence over 90%.
- **Claude Code** (CC) reads the same numbers through MCP, adds findings and can send the matching suggestions. Its findings are marked like its suggestions.
- A finding links to its suggestion: “waiting in Pricing” (purple) or “waiting in Review & Push” (blue). Acted-on findings show their before-and-after result once 28 days have passed.

## For Claude Code

- Ask once per app with `POST /v1/analyticsReportRequests`, access types `ONGOING` and `ONE_TIME_SNAPSHOT`, only after the person presses Ask Apple for Reports. That and Stop Asking are the only writes Analytics makes.
- Download daily instances each morning (or when Analytics opens, per Settings). Keep them on the Mac; compute everything locally.
- Sales: `GET /v1/salesReports` with the vendor number, report types for subscriptions, subscription events and subscribers.
- One shared function computes rate, range, verdict and meter, so Funnel, Break It Down, Subscriptions and After Changes always agree.
- Changes come from Atlas’s push log: date, what, where, languages and territories. Each kind maps to the step it should move.
- MCP: read-only tools for the funnel, breakdown and subscriptions, plus `add_finding`, which lands in What to Try marked CC.

To validate: whether 30 / 3 is the right “too few” line for very small apps; whether people want a weekly digest notification; and whether the subscription reports in the Analytics Reports API remove the need for the vendor number.
