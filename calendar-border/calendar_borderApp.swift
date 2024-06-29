import SwiftUI

@main
struct BorderToggleApp: App {
  @StateObject private var appController = AppController()

  var body: some Scene {
    MenuBarExtra(
      content: {
        MenuBarExtraContent()
          .environmentObject(appController)
      },
      label: {
        HStack {
          Text("📣📅")
        }
      }
    )
  }
}
