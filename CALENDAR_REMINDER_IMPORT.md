# Calendar import & Reminder import (v2)

Settings → Preferences → **Calendar import** and **Reminder import**. Both rows
used to show "isn't available yet"; they now open real screens. Everything the
student picks becomes an ordinary task in the Plan, on its day and at its time.

## What a student can import

| Row | Source | iOS | Android |
|---|---|---|---|
| Calendar import | This phone's calendars (iCloud, Google, Outlook/Exchange, Samsung — whatever the phone syncs) | EventKit | CalendarContract |
| Calendar import | Calendar link (Google's secret iCal address, Outlook publish link, Moodle / Canvas feed, university timetable) | ✅ | ✅ |
| Calendar import | Calendar file (`.ics`) | ✅ | ✅ |
| Reminder import | Apple Reminders | EventKit | — (Android has no shared reminders store) |
| Reminder import | Paste a list — one reminder per line, dates like "fri", "30/10 5pm", "by Nov 3" | ✅ | ✅ |

Every source lands on one review screen: pick calendars/lists, how far ahead
(1 week – 3 months), the study tag to file them under, untick anything to leave
out, then **Add N to my plan**.

Importing again is safe. Items already in the plan are shown as "In your plan"
and cannot be re-added; items imported before and since deleted show
"Removed before" and start unticked. The server enforces the same rule, so a
retry after a dropped connection never doubles anything.

Nothing is ever written back: the native bridges have no write methods, and
Android asks for `READ_CALENDAR` only.

## Where the code is

| Layer | File |
|---|---|
| Settings rows | `lib/features/settings/presentation/settings_home_screen.dart` (push the routes below) |
| Routes | `Routes.settingsCalendarImport`, `settingsReminderImport`, `importReview`, `importPaste` in `core/router/app_router.dart` |
| Screens | `lib/features/import/presentation/` — source pickers, review, paste, link sheet |
| State | `lib/features/import/providers/import_session.dart` — one import at a time, from read to result |
| Model | `lib/data/models/import_item.dart` (plain classes — no codegen) |
| Data | `lib/data/sources/import_source.dart` (mock + API), `lib/data/repositories/import_repository.dart` (batches of 100) |
| Parsing | `lib/services/device_import/ics_parser.dart` (TZID, RRULE, EXDATE, RECURRENCE-ID), `text_list_parser.dart`, `import_mapping.dart` |
| Native bridge | `lib/services/device_import/device_import_service.dart` ⇄ `ios/Runner/DeviceImportPlugin.swift`, `android/.../DeviceImportPlugin.kt` (channel `aqademiq/device_import`) |
| Link download | `lib/services/device_import/ics_fetcher.dart` — its own bare Dio, so the Aqademiq session token never goes to a calendar host |
| Backend | `POST /v1/integrations/import` and `…/import/check` — contract §17 |

After an import the session invalidates `dayTasksProvider` and runs
`reminderScheduler.reconcile(force: true)`, the same two refreshes Add task does.

## Platform setup (already in this branch)

- **iOS** — `Info.plist` has `NSCalendarsFullAccessUsageDescription`,
  `NSCalendarsUsageDescription`, `NSRemindersFullAccessUsageDescription` and
  `NSRemindersUsageDescription`. iOS 17+ reads the FullAccess keys and earlier
  versions the plain ones; a missing key crashes on the first request, so keep
  all four. `DeviceImportPlugin.swift` is in the Runner target's Sources phase
  and registered in `AppDelegate.didInitializeImplicitFlutterEngine`.
- **Android** — `READ_CALENDAR` in `AndroidManifest.xml`; the prompt appears
  when the student taps "This phone's calendars", never at launch.
  `DeviceImportPlugin` is added in `MainActivity.configureFlutterEngine`.

## Testing

```sh
flutter test test/ics_parser_test.dart test/text_list_parser_test.dart test/import_mapping_test.dart
```

On a device (mocks are fine — imported items land in the mock plan):

1. Settings → Calendar import → This phone's calendars → allow → pick a range → Add.
2. Repeat: everything now shows "In your plan" and the button stays disabled.
3. Delete one imported task in the Plan, import again: it shows "Removed before", unticked.
4. Calendar link: paste a Google "secret address in iCal format".
5. Reminder import → Paste a list → "Essay draft fri\nLab report 30/10 5pm" → Preview.
6. iPhone: Reminder import → Apple Reminders.
7. Deny the permission once: the snackbar offers Settings.

## Known limits

- A calendar event becomes one task per occurrence in the chosen range (up to
  3 months), not a repeating task. Import again later for the next stretch.
- If an event's time changes in the source calendar after it was imported, the
  next import sees a new occurrence; the old task stays until deleted.
- RRULE parts `BYSETPOS`, `BYHOUR`, `BYWEEKNO` and `BYYEARDAY` are not
  expanded: such an event keeps only its first occurrence rather than risk
  landing on the wrong days. Phone calendars are unaffected (the OS expands
  them).
- The review list shows at most 500 items at once; anything beyond appears on
  the next import.
