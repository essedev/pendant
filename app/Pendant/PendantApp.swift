import PendantKit
import SwiftUI

@main
struct PendantApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var model = AppModel.shared

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
    }
    .onChange(of: scenePhase) { _, phase in
      model.log.record("scene", "\(phase)")
    }
  }
}

/// The three tabs, and the first launch over them.
struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    TabView(selection: $model.tab) {
      Tab("Adesso", systemImage: "waveform", value: AppModel.Tab.now) {
        NavigationStack { NowView() }
      }
      Tab("Oggi", systemImage: "list.bullet", value: AppModel.Tab.today) {
        NavigationStack(path: $model.todayPath) { TodayView() }
      }
      Tab("Impostazioni", systemImage: "slider.horizontal.3", value: AppModel.Tab.settings) {
        NavigationStack(path: $model.settingsPath) { SettingsView() }
      }
    }
    .tint(Theme.ink)
    .fullScreenCover(
      isPresented: Binding(
        get: { model.onboarding != nil }, set: { if !$0 { model.onboarding = nil } })
    ) {
      OnboardingView(start: model.onboarding ?? .welcome)
        .environment(model)
    }
  }
}
