import Combine
import EventKit
import ServiceManagement
import SwiftUI

struct BadEvent: Hashable {
  var id: String
  var title: String
  var ignore: Bool = false
}

struct BadCalendar: Hashable {
  var id: String
  var title: String
  var color: NSColor
}

enum AlertTime: Int, CaseIterable {
  case tenMinutes = 10
  case fiveMinutes = 5
  case onAlarm = 0
}

class AppController: ObservableObject {
  struct Constants {
    static let helperBundleId = "Joe-Woods.AutoLauncher"
  }

  private var isInitializing = true
  @Published var gavePermission = false
  private let userDefaults = UserDefaults.standard

  @Published var launchAtLogin = false {
    didSet {
      SMLoginItemSetEnabled(Constants.helperBundleId as CFString, launchAtLogin)
    }
  }

  @Published private var calendarEvents: [EKEvent] = []
  @Published private var borderWindowController: BorderWindowController
  @Published private var isBorderVisible: Bool = false
  @Published var ignoredCalendars = Set<String>()
  @Published var alertingEvents: [BadEvent] = []
  @Published var availableCalendars: [BadCalendar] = []

  @Published var useAnimation: Bool = true {
    didSet {
      if !isInitializing {
        userDefaults.set(useAnimation, forKey: "useAnimationKey")
      }
    }
  }
  @Published var alertTime: AlertTime = AlertTime.tenMinutes {
    didSet {
      if !isInitializing {
        userDefaults.set(alertTime.rawValue, forKey: "alertTimeKey")
      }
    }
  }

  init() {
    useAnimation = userDefaults.bool(forKey: "useAnimationKey")
    alertTime =
      AlertTime(rawValue: userDefaults.integer(forKey: "alertTimeKey")) ?? AlertTime.tenMinutes
    if let array = userDefaults.array(forKey: "ignoredCalendarsKey") as? [String] {
      ignoredCalendars = Set(array)
    } else {
      print("Error: Unable to retrieve array from UserDefaults or array does not contain strings.")
    }
    isInitializing = false

    borderWindowController = BorderWindowController()
    borderWindowController.setAppController(appController: self)
    fetchCalendarEvents()
    requestCalendarAccess()
  }

  func toggleIgnoreFor(event: BadEvent) {
    let newEvents = alertingEvents.map { originalEvent in
      var updatedEvent = originalEvent
      if updatedEvent.id == event.id {
        updatedEvent.ignore.toggle()
      }
      return updatedEvent
    }

    alertingEvents = newEvents
    // silly, but let's make this happen as quickly as possible:
    checkForUpcomingAlarms()
  }

  func ignoreCalendar(calendar: BadCalendar, newType: Bool) {
    if newType {
      ignoredCalendars.remove(calendar.id)
    } else {
      ignoredCalendars.insert(calendar.id)
    }
    userDefaults.set(Array(ignoredCalendars), forKey: "ignoredCalendarsKey")
    checkForUpcomingAlarms()
  }

  func setAlertTime(time: AlertTime) {
    alertTime = time
    print(time, alertTime)
  }

  func quitApp() {
    NSApplication.shared.terminate(nil)
  }

  func toggleBorder() {
    isBorderVisible.toggle()
    if isBorderVisible {
      borderWindowController.hideBorder()
    } else {
      borderWindowController.showBorder()
    }
  }

  func requestCalendarAccess() {
    let store = EKEventStore()

    store.requestFullAccessToEvents {
      (granted, error) in
      DispatchQueue.main.async {
        if let error = error {
          print("Error requesting calendar access: \(error.localizedDescription)")
          self.gavePermission = false
          return
        }

        if granted {
          self.gavePermission = true
          print("Access granted, proceed to access the calendar")
          Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { timer in
            self.checkForUpcomingAlarms()
          }
          self.checkForUpcomingAlarms()
        } else {
          self.gavePermission = false
          print("nope", granted, EKEventStore.authorizationStatus(for: EKEntityType.event).rawValue)
        }
      }
    }
  }

  func fetchCalendarEvents() {
    let eventStore = EKEventStore()
    let calendars: [EKCalendar] = eventStore.calendars(for: EKEntityType.event)
    var newCalendars: [EKCalendar] = []
    var newCache: [BadCalendar] = []
    calendars.forEach({ calendar in
      let cached = availableCalendars.first(where: { thisCalendar in
        if thisCalendar.id == calendar.calendarIdentifier {
          return true
        }
        return false
      })

      // if we don't have the calendar cached, just add it to the cache and move
      // on.
      if let unwrappedValue: BadCalendar = cached {
        newCache.append(unwrappedValue)
        if ignoredCalendars.contains(calendar.calendarIdentifier) {
          print("ignoring!", unwrappedValue)
        } else {
          newCalendars.append(calendar)
        }
      } else {
        // There's probably a tidier way to build this dictionary on the first
        // pass, but… I'm feeling lazy.
        newCache.append(
          BadCalendar(id: calendar.calendarIdentifier, title: calendar.title, color: calendar.color)
        )
        return
      }
    })

    availableCalendars = newCache.sorted {
      $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
    }
    print("number of calendars:", newCalendars.count)

    let oneHourAgo = Date().addingTimeInterval(-1 * 60 * 60)
    let oneHourFromNow = Date().addingTimeInterval(60 * 60)

    let predicate = eventStore.predicateForEvents(
      withStart: oneHourAgo, end: oneHourFromNow, calendars: newCalendars)

    calendarEvents = eventStore.events(matching: predicate)
    print("number of events:", calendarEvents.count)
  }

  func checkForUpcomingAlarms() {
    print("first, let's fetch our calendar events…")
    fetchCalendarEvents()
    print("okay let's look for upcoming alarms")

    let now = Date()
    var theseAlertingEvents: [BadEvent] = []
    for event in calendarEvents {
      // not really concerned with all day events
      if event.isAllDay {
        continue
      }

      if let occurrenceDate = event.occurrenceDate {
        if alertTime == AlertTime.onAlarm {
          if let alarms = event.alarms {
            for alarm in alarms {
              let triggerDate = occurrenceDate.addingTimeInterval(alarm.relativeOffset)

              if triggerDate < now, triggerDate < occurrenceDate, occurrenceDate > now {
                let ignore =
                  alertingEvents.first(where: { $0.id == event.eventIdentifier })?.ignore ?? false
                theseAlertingEvents.append(
                  BadEvent(id: event.eventIdentifier, title: event.title, ignore: ignore))
              }
            }
          }
        } else {
          let futureTime = now.addingTimeInterval(
            (alertTime == AlertTime.tenMinutes ? 10 : 5) * 60)

          if occurrenceDate <= futureTime, occurrenceDate > now {
            let ignore =
              alertingEvents.first(where: { $0.id == event.eventIdentifier })?.ignore ?? false
            theseAlertingEvents.append(
              BadEvent(id: event.eventIdentifier, title: event.title, ignore: ignore))
          }
        }

      }
    }
    print("alarms:", theseAlertingEvents)
    alertingEvents.removeAll()
    alertingEvents.append(contentsOf: theseAlertingEvents)
    if theseAlertingEvents.contains(where: { !$0.ignore }) {
      showBorder()
    } else {
      hideBorder()
    }
  }

  func showBorder() {
    borderWindowController.showBorder()
    isBorderVisible = true
    print("okay I should have shown the border")
  }

  func hideBorder() {
    borderWindowController.hideBorder()
    isBorderVisible = false
  }
}
