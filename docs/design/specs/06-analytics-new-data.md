ATLAS · ANALYTICS · NEW DATA FROM APPLE · 22 NOVEMBER 2026

# Analytics: what Apple now tells us after the download

Apple’s Analytics Reports API carries more than the funnel uses today: what happens on the cancel screen, which page and campaign each subscriber came from, billing failures, crashes by version, deletions, sessions, the web preview and widgets. This design puts each where a decision is made, and keeps the rule of Analytics: every number leads to an action or is left out.

**On the canvas** (page *Analytics*, below boards 29–37): the prototype (press Play; tabs, sub-tabs and the sidebar work), and boards **59** Retention Messaging, **60** subscribers by page, campaign and offer, **61** crashes and the release, **62** second phase, Claude Code and report states. The prototype is its own component for now; once approved it moves into the clickable app. The numbers are examples for Lumen Journal and add up with boards 31–35.

**Not checked against Apple.** Report names, fields and dates come from the brief. I didn’t verify them against Apple’s documentation or a real download, and three actions need an API check before they’re built: turning on Billing Grace Period, pausing a phased release from this alert, and reading a review’s app version.

## Where each report shows

| Report | Shown in | Board | Phase |
| --- | --- | --- | --- |
| Retention Messaging | Analytics → Subscriptions → **Retention**, a block in the Summary, and beside each message in Pricing → Retention | 59 | 1 |
| App Store Subscription Event, Subscription State | Break It Down → Product Page and **Campaign**; Product Pages list; Subscriptions → **Offers** and **Billing and Plans** | 60 | 1 |
| App Crashes | A new view, **Stability**; an alert on Overview during a phased release; a banner in Reviews | 61 | 1 |
| App Store Installations and Deletions | Column “Deleted in 30 days” in Break It Down; findings | 60, 61 | 1, as a column |
| App Sessions | Column “Sessions / week”; the denominator of crash rates | 60, 61 | 1, as a column |
| App Store Web Preview | A row under the funnel, “On the web” | 62 | 2 |
| Home Screen Widget Installs | A number under the funnel; evidence in a Screenshots finding | 61, 62 | 2 |

## Decisions

- **Subscriptions gets four views:** Summary, Retention, Offers, Billing and Plans. One page couldn’t hold them, and each answers a different question. The Summary keeps board 35 and adds a Retention block, a billing line and a pointer to the page breakdown.
- **Stability is a sixth view in Analytics.** The earlier README left crashes out because they didn’t lead to an edit in Atlas. They do now: Pause Phased Release.
- **Save rate uses the same “how sure” as every other rate:** the 90% range, the three-bar meter, and Better, Worse or About the same only when the whole range is clear. Each message is compared with **No Message**, the reference, never with the average.
- **“With a message, or without”** is its own small chart, because it answers whether retention messaging is worth doing at all.
- **Too few to tell** follows the existing line: under 30 people at the cancel screen, counts replace the rate (“3 of 14”), with no verdict.
- **The last 4 days are left out** of retention numbers, since Apple completes a day up to 4 days later. The pill says “Retention through Nov 5” while the rest says Nov 9.
- **In Pricing → Retention the numbers sit beside each message,** on the right of its card, with one line saying where they come from and a link to Analytics. Editing stays as on board 28.
- **Break It Down keeps one table.** Columns are in three groups (Store, Subscribers, After download); the boards show the last two. Campaign is a new way to break down; In-App Event pages are rows of Product Page.
- **Paid subscribers in the Product Pages list** use the same numbers as Break It Down, and say “of 58 trials” under the count.
- **Offers show “Paid afterwards”**, the first charge at the regular price. An offer too young to have one says when it will, instead of a rate.
- **Involuntary churn is a finding, not a chart.** Couldn’t be charged → recovered → lost, then one action. It doesn’t promise how many grace period would save: that isn’t known until it’s on.
- **Crash rate is crashes per 1,000 sessions,** the new version against the previous one on the same days, so a growing rollout doesn’t look like a growing problem.
- **The release alert shows only when** the new version is worse and Atlas is at least fairly sure. It appears on Overview, in Stability, in Reviews, in the menu bar and as a notification. Pausing always asks first.
- **Deletions and sessions are a sample.** They only count people who share analytics with developers. Every table and finding that uses them says so once, in its footer or its “how sure” line.
- **Web preview and widgets stay small:** two rows under the funnel, and a finding only when they bear on something editable (reviews without a reply, a screenshot about a widget few add).

## Findings Atlas makes from this (built-in rules)

| When | Finding | Action |
| --- | --- | --- |
| A message’s save rate is clearly above another’s that runs elsewhere | “The offer message keeps 31% of people. The text-only one keeps 17%.” | Show This Message in …; Try an Offer Message… |
| No Message is clearly below messages | “People who see no message stay half as often.” | Write Messages for N Languages… |
| Lost to billing ≥ 10 a month and grace period off | “You lose about N subscribers a month to billing issues.” | Turn On Billing Grace Period… |
| A page’s deletions are clearly above the default page’s | “People who arrive through X delete the app twice as often.” | Open the page; Make Screenshots for This Page… |
| Deletions rise with a version, crashes don’t | “Deletions rose with version 1.3.1.” | See After Changes |
| Crash rate clearly above the previous version during a phased release | The alert | Pause Phased Release… |
| An offer’s paid-afterwards rate is clearly below average | “PODCAST30 brought 60 people and 4 stayed.” | Open Pricing |

“Rewrite the header” is left to Claude Code: it needs reading the messages, which a rule can’t do.

## States and their copy

| State | Copy |
| --- | --- |
| Asking Apple (first read) | Apple is preparing 8 more reports for {app}. Asked on {date}; the first ones usually take 1 to 2 days. The funnel keeps working meanwhile, and each view fills in as its report arrives. |
| Report with no rows | No rows yet · Apple has sent the report, empty |
| Retention, no data yet | No one has opened Cancel Subscription yet · Apple’s Retention Messaging report starts when a subscriber reaches the cancel screen. {app}’s message went live on {date} and nobody has been there since. That’s good news; the save rate appears here when someone does. |
| Retention, few data | Too few to tell. Rates this small move by chance, so they’re shown as counts until 30 people have opened the cancel screen. |
| Retention, still arriving | {date} to {date} are still arriving. Apple completes each day up to 4 days later, so the newest days are left out until then. |
| Offer too young | — · first renewals from {date} · Still measuring |
| A sample | Deletions and sessions come from people who share analytics with developers, so they’re a sample. Apple leaves out rows with fewer than 5 people. |

Tidepool, an example app, is the “no data yet” case: its message is live and nobody has reached the cancel screen (board 59).

## Claude Code, through MCP

- **Reads** (no side effects): `analytics_retention`, `analytics_subscribers`, `analytics_subscription_states`, `analytics_crashes`, `analytics_after_download`, `analytics_web_preview`. Each takes the app, the period and what to break down by, and returns counts with the rate, range and verdict already computed, so Claude Code and Atlas never disagree on “sure”.
- **Writes:** `add_finding` (lands in What to Try marked CC) and the existing suggestion tools for retention messages, product pages and texts, which arrive in purple and wait for you.
- **A CC finding shows what it read,** as the list of calls, so you can judge it (board 62).
- **Never through MCP:** pausing a release, changing billing settings, pushing. Those stay buttons.

## For Claude Code (building it)

- The existing report request already covers these: they’re more reports of the same `analyticsReportRequest`. For apps asked before this version, list the request’s reports and start downloading the new ones; show “Asked” only for apps that never asked. Keep per-report status (ready, through which day, a sample, no rows).
- Join subscription events to pages, campaigns and sources by the fields the report gives; don’t infer origin from dates.
- Retention: store page views, cancels and saves per day and per message, type, offer, save type, subscription, territory, device. Save rate = 1 − cancels ÷ page views. Exclude the last 4 days from every retention figure.
- Crash rate needs App Crashes and App Sessions for the same version, device and day; if sessions are missing, show counts and no rate.
- The shared rate function (range, meter, verdict, too few) from boards 29–37 computes all of this.
- Billing Grace Period and Pause Phased Release are writes: confirm first, log in History, and check the API supports them with the key’s role before showing the button.

To validate: the report fields against a real download; whether “Deleted in 30 days” can be computed per page from what Apple gives, or only deletions ÷ installs in the period; whether Stability deserves a tab for apps with little traffic, or should appear only when a version is rolling out; and whether Offers belongs in Analytics or in Pricing next to each offer.
