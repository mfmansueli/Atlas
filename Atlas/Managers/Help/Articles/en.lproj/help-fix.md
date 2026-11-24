---
id: fix
group: atlas
title: Fix a problem
summary: The few things that go wrong, and what to do.
keywords: problem, error, refused, revoked, sales, push stopped, failed, offline, connection, cant connect, can't connect, assistant, token, troubleshoot
showMe: settings:accounts
related: connect, assistant
---
## The key was refused

The key was revoked, or its IDs don’t match the .p8 file. Make a new key and add it in Settings → Accounts.

## Atlas can’t read sales

The key’s role is App Manager or Developer. Sales, trials and proceeds need Admin, Finance or Sales.

## A push stopped halfway

What already landed stays on the App Store. The rest is still in Review & Push, each with Apple’s reason. Fix and push again.

## Apple can’t be reached

Your edits are kept on this Mac. Atlas tries again when the connection is back. Check Apple’s system status from the Help menu.

## The key can’t do that

The key’s role doesn’t allow this change. Pushing needs an Admin or App Manager key. Add one in Settings → Accounts.

## Apple can’t find it

It was deleted or renamed in App Store Connect since Atlas read it. Refresh the section, then make the change again.

## Apple refused a change

Apple’s reason is under Details. Fix the field it names, then push again. The other changes aren’t affected.

## Apple’s hourly limit was reached

App Store Connect allows a few thousand requests an hour per key. Nothing is lost: wait a few minutes and try again.

## Apple didn’t answer

App Store Connect is slow or down for a moment. Try again in a minute, or check Apple’s system status from the Help menu.

## An assistant won’t connect

Check that Let assistants connect is on and that Atlas is running. If you made a new token, pair the assistant again.
