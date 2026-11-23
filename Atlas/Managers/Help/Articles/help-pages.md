---
id: pages
group: listing
title: Product pages for an audience
summary: Other versions of your App Store page, each with its own link, for an audience, a campaign or a search.
keywords: custom product pages, product page, product pages, page, pages, link, campaign, audience, deep link, visible, hidden, 70, promotional text, keywords, not offered, rules, screenshots, make screenshots for this page, autopilot, look, template, claude design, capture again, simulator, choose files, sizes, app review, approved, rejected, notification, app previews, video, choose app previews, campaign, referrer
showMe: section:productPages
related: store, submit, analytics
---
A custom product page changes what people see first: its screenshots, App Previews and promotional text, in each language. The name, icon and description stay the same as the default page’s. An app can have up to 70 pages.

## Make a page

1. Click **New Page…**, give it a name, and choose what it starts from: the default page, a copy of another page, or nothing.
2. Write its promotional text and choose its keywords in each language that needs its own.
3. Click **Submit for Review…**. Review & Push opens on that page’s changes (switch to the whole app above the list) and sends them to App Store Connect, then **Submit for Review** sends the page to App Review by itself, with no new version of the app.

Once Apple approves it, the page’s link works. Turn **Visible** on to show it for the keywords you chose; that needs no review.

While App Review has a page, Atlas looks at it each time it checks App Store Connect and tells you when it’s in review, approved or sent back, with a notification when Settings → Notifications has **App Review changes a version’s or an event’s status** on. Atlas can’t show the reviewer’s message: it’s in App Store Connect.

## Screenshots for a page

A page shows the default page’s screenshots until it has its own. To make them, click **Make Screenshots for This Page…** under the page’s screenshots (Atlas Pro).

1. Your assistant plans the set for the page’s audience: which of the default page’s screens come first, and a caption for each in every language. Change the angle if you like, and choose the languages and devices that get the page’s own images.
   - **Look:** keep the default page’s template, pick **Another template…** from Atlas’s templates, or choose **A new look from Claude Design**: your assistant draws three looks, each shown on the page’s first screenshot, and you click the one to use.
   - **Capture screens again:** turn it on and your assistant runs the app in the Simulator and captures again the screens that should show something else for this page (at most 3), such as the lock turned on. Each is marked “captured again”; **Use the Default** puts a screen back. The default page’s captures don’t change.
2. Click **Start Autopilot**. Atlas lays the set out with the look you chose, from the default page’s captures and the ones captured again. Close the window whenever you like: Autopilot keeps going, and the page shows how far it got.
3. Look at the new set beside the default page’s. **Ask for Changes…** tells your assistant what to change, and only this page’s set is redone.
4. Click **Use These Screenshots**. They wait in Review & Push, one change per language and device, until you push and submit the page.

Have App Preview videos for the page? Click **Choose App Previews…** and pick up to 3 MOV, MP4 or M4V videos for the language and device shown: 886 × 1920 on iPhone or 1200 × 1600 on iPad (either way round), 15 to 30 seconds, up to 500 MB. They wait in Review & Push like the screenshots, and the default page’s App Previews don’t change.

Already have the screenshots? Click **Choose Files…** under the page’s screenshots and pick up to 10 PNG or JPEG images for the language and device shown. Atlas checks each one’s size first: iPhone takes 1320 × 2868, 1290 × 2796 or 1260 × 2736, and iPad 2064 × 2752 or 2048 × 2732, upright or turned. A file that doesn’t fit is named with the sizes that work, and nothing is added. The ones that fit wait in Review & Push, in place of any set chosen before for that language and device.

The default page’s screenshots, captions and template don’t change.

## Where a page’s link is used

Under a page’s numbers, the list says where its visitors came from over the last 28 days: a campaign link (its `ct` token) or the app or website that links to it, the one with the most page views first. Hold the pointer over it for the rest. It comes from Apple’s detailed reports, like **Analytics → Break It Down → Referrer** and **Campaign**.

## If a push didn’t finish

When Apple takes too long to answer, a page may still have been made in App Store Connect. Atlas never retries that on its own: after **Refresh**, a draft App Store Connect already has becomes that page, and what it still needs (keywords, texts, the deep link) waits in Review & Push.

## What promotional text can’t say

Apple rejects store text that talks about prices or offers, so Atlas stops an assistant’s text that does and shows it as **Not offered**, with the words marked.

- No prices, “free” in any language, discounts or trial lengths. The App Store shows the price and offers itself.
- No other platforms or app stores, such as Android or Google Play.
- No beta, demo or “coming soon”, and no placeholder text.
- Only what this version of the app really does.

> **Ask for Another** asks your assistant for a new text that follows these rules.

## Keywords

A page’s keywords come from the last version Apple approved, and each keyword leads to one page. Choosing one another page has moves it here, after you confirm.
