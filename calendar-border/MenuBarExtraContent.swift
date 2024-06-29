import AppKit
import SwiftUI

struct MenuBarExtraContent: View {
  @EnvironmentObject var appController: AppController

  var body: some View {
    VStack {
      if !appController.gavePermission {
        Text(
          "We don't have permission to access your calendar to check for upcoming events."
        )
        .foregroundColor(.gray)
        Text("(We need full access, not 'add only'!)").foregroundColor(.gray)
        Button(action: {
          let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
          NSWorkspace.shared.open(url)
        }) {
          Text("Go to settings")
        }
        Button(action: {
          appController.requestCalendarAccess()
        }) {
          Text("Check permissions again")
        }
      } else {
        if appController.alertingEvents.isEmpty {
          Text("No upcoming events")
            .foregroundColor(.gray)
        } else {
          ForEach(appController.alertingEvents, id: \.self) { event in
            Text("📅 " + event.title)
            Button(event.ignore ? "Show" : "Ignore") {
              appController.toggleIgnoreFor(event: event)
            }
          }
        }

        Divider()

        Menu("Preferences") {
          Menu("Alert time") {
            ForEach(AlertTime.allCases, id: \.self) { time in
              Toggle(
                time.rawValue == 0
                  ? "On calendar notification" : "\(time.rawValue) minutes before event",
                isOn: Binding(
                  get: {
                    return appController.alertTime == time
                  },
                  set: {
                    if $0 {
                      appController.alertTime = time
                    }
                  }
                )
              )
            }
          }
          Menu("Enabled calendars") {
            if appController.availableCalendars.isEmpty {
              Text(
                "You can't ignore any calendars if you don't have any.  How don't you have any calendars?"
              )
              .foregroundColor(.gray)
            } else {
              ForEach(appController.availableCalendars, id: \.self) { calendar in
                Toggle(
                  isOn: Binding(
                    get: {
                      return !appController.ignoredCalendars.contains(calendar.id)
                    },
                    set: {
                      appController.ignoreCalendar(calendar: calendar, newType: $0)
                    })
                ) {
                  Text("●")
                    .foregroundStyle(Color(nsColor: calendar.color)) + Text(" " + calendar.title)
                }
                .padding()
              }
            }
          }
          Toggle(isOn: $appController.useAnimation) {
            Text("Use animation")
          }
          // TODO:  this doesn't actually work!
          // Button(action: {
          //   appController.launchAtLogin = true
          //   let url = URL(
          //     string: "x-apple.systempreferences:com.apple.preference.users?LoginItems")!
          //   NSWorkspace.shared.open(url)
          // }) {
          //   Text("Add to list of apps that launch on login")
          // }
        }

        Divider()

        Button("Quit") { appController.quitApp() }
          .keyboardShortcut("Q")
      }

    }
  }
}

@available(macOS 13.0, *)
struct MenuBarExtraContent_Previews: PreviewProvider {
  static var previews: some View {
    MenuBarExtraContent().environmentObject(AppController())
  }
}
