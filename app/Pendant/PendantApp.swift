import PendantKit
import SwiftUI

@main
struct PendantApp: App {
  var body: some Scene {
    WindowGroup {
      Text("Pendant \(PendantKit.version)")
    }
  }
}
