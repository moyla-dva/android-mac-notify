# Notification Routing

This document describes the current notification and event routing strategy.

The product goal is not to mirror every Android notification onto Mac. Android Mac Notify should only cross the device boundary when the event is useful on the Mac.

## 1. Current Default

Current default behavior:

```text
Android notifications automatically relay only verification codes and links.
Files relay through explicit user sharing.
Other notifications stay on the phone by default.
```

This keeps the Mac from becoming a second Android notification shade.

## 2. Event Sources

Current sources:

- Android notification listener
- Android system share sheet
- Android in-app file picker
- Device session state, including active, paused, Mac paused, and unreachable

Future sources may include:

- Explicit user-configured app/contact/channel rules
- Call events
- External status providers such as logistics or calendar integrations
- Mac activity or focus state

Future sources should still produce typed events rather than raw notification mirrors.

## 3. Pipeline

The current product pipeline is:

```text
Android Event
  -> Android Relay Gate
  -> Local HTTP Transport
  -> Mac Receiver
  -> Action Classification
  -> Mac Surface
```

The important boundary is the Android relay gate. If an event is not useful across devices, it should not be sent to the Mac at all.

## 4. Android Relay Gate

Android decides whether a phone-side event is worth crossing the device boundary.

Default send:

- Verification codes, dynamic codes, login codes, and security codes
- Notification title or body containing an actionable link
- Files explicitly shared to Android Mac Notify

Default skip:

- Ordinary WeChat, QQ, Telegram, DingTalk, Feishu, and other chat text
- File Transfer Assistant or Saved Messages ordinary text
- Food delivery, express delivery, pickup, order progress, and other weakly deterministic status notifications
- Ordinary payment success, login success, or security awareness notifications
- Commerce marketing, content recommendations, channel feeds, membership benefits, traffic-package promotions
- Ongoing system status, media playback, download, upload, sync, battery, and VPN state

The gate should stay conservative until there is a user-facing configuration or diagnostics surface.

## 5. Mac Surfaces

Events that pass the Android gate can land on these Mac surfaces:

| Surface | Role | Default use |
| --- | --- | --- |
| Menu bar | Fastest action surface | Verification code, link, recent file result |
| Action inbox | Deferred handling | Unfinished actionable notifications |
| File delivery cards | File-specific receipt and actions | Open, reveal, copy path |
| Recent history | Lightweight audit trail | Recordable non-sensitive handled events |
| Settings / diagnostics | Reliability and connection details | Pairing, receiver, storage, network state |
| Discard | No Mac-side value | Empty, duplicate, skipped, or sensitive long-term content |

System notifications are not the default output for ordinary relay events. They should be reserved for exceptional feedback or future explicit high-priority cases.

## 6. Action Priority

If an event can produce a clear action, treat it as an action event first.

Current priority:

1. Copy verification code
2. Open link
3. Copy text, only when the event is explicitly allowed
4. File actions: open, reveal, copy path

Successful actions should exit the pending area. They may remain as lightweight handled history when safe.

## 7. Persistence And Privacy

Default persistence rules:

- Verification codes are transient and should not enter long-term history
- Sensitive notification body content should not be written when a short-lived action is enough
- File receipts can be retained because they point to files saved on the Mac
- Failed actions can remain visible long enough to retry or understand what happened
- Duplicate event IDs should not create duplicate user-facing cards

Persistence should be based on event type and surface, not on whether a notification was technically received.

## 8. Current Implementation

Current implementation facts:

- Android `AndroidNotificationRelayGate` runs before queueing and HTTP delivery
- Empty notifications, ongoing status, ordinary IM, high-confidence marketing, and system noise are skipped on Android
- Verification codes and links are sent to Mac
- Mac trusts the Android gate and no longer maintains a second marketing-rule engine
- Mac menu bar and action inbox are the default handling surfaces
- Successful actions are persisted by action ID and leave the pending area across restart
- File delivery uses independent file cards and does not mix into the ordinary notification inbox
- Status card providers are not triggered by the default Android notification path

## 9. Known Limits

Current limits:

- Android relay rules are not user-configurable yet
- There is no Android-side "recently skipped / allowed reason" diagnostics page
- The app cannot identify contact-level or channel-level user preference yet
- Marketing and content rules can still have false positives or false negatives
- Status cards are intentionally deferred unless introduced through explicit configuration or external providers

## 10. Future Decisions

Next notification-routing work should prioritize:

1. Android diagnostics for skipped and allowed events
2. Minimal user configuration for app, contact, channel, or keyword rules
3. Explicit providers for call, meeting, or external status events
4. Mac activity-aware routing strength
5. User feedback such as "keep this", "quiet this", or "history only"

Avoid expanding keyword lists endlessly. Better routing should come from clear event sources, explicit user control, and observable feedback.
