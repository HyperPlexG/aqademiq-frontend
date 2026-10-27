import EventKit
import Flutter
import UIKit

/// Reads the phone's calendars and Apple Reminders for Settings → Calendar
/// import and Reminder import (lib/services/device_import/device_import_service.dart).
///
/// Read-only by construction: nothing here saves, edits or removes an event or
/// a reminder, so an import can never change the student's own calendar.
///
/// The calendars include every account the iPhone syncs — iCloud, Google,
/// Outlook / Exchange, subscribed calendars — because they all live in
/// EventKit. Repeating events arrive already expanded, one per occurrence.
final class DeviceImportPlugin {
  static let channelName = "aqademiq/device_import"

  private let channel: FlutterMethodChannel

  /// Created on first use, not at launch: most sessions never import.
  private lazy var store = EKEventStore()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      let args = call.arguments as? [String: Any] ?? [:]
      let type: EKEntityType = (args["kind"] as? String) == "reminders" ? .reminder : .event
      switch call.method {
      case "requestAccess":
        self.requestAccess(type, result: result)
      case "calendars":
        self.calendars(type, result: result)
      case "events":
        self.events(args, result: result)
      case "reminders":
        self.reminders(args, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - access

  /// Compared by raw value on purpose. iOS 17 renamed `.authorized` to
  /// `.fullAccess` (both 3) and added `.writeOnly` (4, which cannot read);
  /// naming either case would need availability checks on the iOS 13 target.
  private static func canRead(_ type: EKEntityType) -> Bool {
    EKEventStore.authorizationStatus(for: type).rawValue == 3
  }

  private func requestAccess(_ type: EKEntityType, result: @escaping FlutterResult) {
    if DeviceImportPlugin.canRead(type) {
      result(true)
      return
    }
    let completion: (Bool, Error?) -> Void = { [weak self] granted, _ in
      DispatchQueue.main.async {
        // A store created before access was granted can go on returning
        // nothing, so reads start from a fresh one.
        if granted { self?.store = EKEventStore() }
        result(granted && DeviceImportPlugin.canRead(type))
      }
    }
    if #available(iOS 17.0, *) {
      if type == .reminder {
        store.requestFullAccessToReminders(completion: completion)
      } else {
        store.requestFullAccessToEvents(completion: completion)
      }
    } else {
      store.requestAccess(to: type, completion: completion)
    }
  }

  private static func denied(_ result: FlutterResult) {
    result(FlutterError(code: "denied", message: "Access was not granted", details: nil))
  }

  // MARK: - calendars

  private func calendars(_ type: EKEntityType, result: @escaping FlutterResult) {
    guard DeviceImportPlugin.canRead(type) else { return DeviceImportPlugin.denied(result) }
    let rows: [[String: Any]] = store.calendars(for: type).map { calendar in
      var row: [String: Any] = [
        "id": calendar.calendarIdentifier,
        "title": calendar.title,
      ]
      if let account = calendar.source?.title, !account.isEmpty { row["account"] = account }
      if let hex = DeviceImportPlugin.hex(calendar.cgColor) { row["color"] = hex }
      return row
    }
    result(rows)
  }

  // MARK: - events

  private func events(_ args: [String: Any], result: @escaping FlutterResult) {
    guard DeviceImportPlugin.canRead(.event) else { return DeviceImportPlugin.denied(result) }
    let ids = Set(args["calendarIds"] as? [String] ?? [])
    let from = Date(timeIntervalSince1970: DeviceImportPlugin.seconds(args["from"]))
    let to = Date(timeIntervalSince1970: DeviceImportPlugin.seconds(args["to"]))
    let calendars = store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
    guard !calendars.isEmpty, to > from else {
      result([[String: Any]]())
      return
    }
    let eventStore = self.store
    // `events(matching:)` is synchronous and can take a moment on a busy
    // calendar, so it stays off the main thread.
    DispatchQueue.global(qos: .userInitiated).async {
      let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: calendars)
      let calendar = Calendar.current
      let rows: [[String: Any]] = eventStore.events(matching: predicate).compactMap { event in
        guard let start = event.startDate, event.status != .canceled else { return nil }
        // The server-side id where there is one (stable across devices and
        // re-syncs); the occurrence start is appended in Dart.
        let id: String = event.calendarItemExternalIdentifier ?? event.eventIdentifier ?? event.calendarItemIdentifier
        var row: [String: Any] = [
          "id": id,
          "title": event.title ?? "",
          "start": DeviceImportPlugin.millis(start),
          "allDay": event.isAllDay,
          "startDay": DeviceImportPlugin.day(start, calendar: calendar),
          "calendarId": event.calendar?.calendarIdentifier ?? "",
          "calendarTitle": event.calendar?.title ?? "",
        ]
        if let end = event.endDate { row["end"] = DeviceImportPlugin.millis(end) }
        if let notes = event.notes, !notes.isEmpty { row["notes"] = notes }
        if let location = event.location, !location.isEmpty { row["location"] = location }
        return row
      }
      DispatchQueue.main.async { result(rows) }
    }
  }

  // MARK: - reminders

  private func reminders(_ args: [String: Any], result: @escaping FlutterResult) {
    guard DeviceImportPlugin.canRead(.reminder) else { return DeviceImportPlugin.denied(result) }
    let ids = Set(args["calendarIds"] as? [String] ?? [])
    let lists = store.calendars(for: .reminder).filter { ids.contains($0.calendarIdentifier) }
    guard !lists.isEmpty else {
      result([[String: Any]]())
      return
    }
    let predicate = store.predicateForIncompleteReminders(
      withDueDateStarting: nil,
      ending: nil,
      calendars: lists
    )
    _ = store.fetchReminders(matching: predicate) { reminders in
      let calendar = Calendar.current
      let rows: [[String: Any]] = (reminders ?? []).compactMap { reminder in
        if reminder.isCompleted { return nil }
        let id: String = reminder.calendarItemExternalIdentifier ?? reminder.calendarItemIdentifier
        var row: [String: Any] = [
          "id": id,
          "title": reminder.title ?? "",
          "listId": reminder.calendar?.calendarIdentifier ?? "",
          "listTitle": reminder.calendar?.title ?? "",
        ]
        if let notes = reminder.notes, !notes.isEmpty { row["notes"] = notes }
        if let components = reminder.dueDateComponents,
           let due = DeviceImportPlugin.date(from: components, calendar: calendar) {
          row["due"] = DeviceImportPlugin.millis(due)
          row["dueHasTime"] = components.hour != nil
        }
        return row
      }
      DispatchQueue.main.async { result(rows) }
    }
  }

  // MARK: - helpers

  /// A reminder's due date as an instant. A date-only reminder is local
  /// midnight; a timed one keeps the zone it was set in.
  private static func date(from components: DateComponents, calendar: Calendar) -> Date? {
    var cal = calendar
    if let zone = components.timeZone { cal.timeZone = zone }
    var c = components
    if c.hour == nil {
      c.hour = 0
      c.minute = 0
      c.second = 0
    }
    return cal.date(from: c)
  }

  private static func millis(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
  }

  private static func seconds(_ raw: Any?) -> TimeInterval {
    guard let number = raw as? NSNumber else { return 0 }
    return number.doubleValue / 1000
  }

  /// The local calendar day, `yyyy-MM-dd`. All-day events start at midnight
  /// of their day, so this is the day the event belongs to.
  private static func day(_ date: Date, calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
  }

  private static func hex(_ color: CGColor?) -> String? {
    guard let color else { return nil }
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard UIColor(cgColor: color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    func byte(_ v: CGFloat) -> Int { max(0, min(255, Int((v * 255).rounded()))) }
    return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
  }
}
