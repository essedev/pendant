import Foundation
import PendantKit

/// Scenes for simulator screenshots, chosen with `-demo <scene>` at launch.
///
/// Each scene fixes the clock at 17:42 of 26 November 2026 and fills the screens with the
/// states of the mock (docs/concepts/concept-b-app.html): the real views render them, with no
/// pendant and no server.
enum DemoScene: String, CaseIterable {
  case homeRec = "home.rec"
  case homePause = "home.pause"
  case homeOff = "home.off"
  case homeQueue = "home.queue"
  case homeCharge = "home.charge"
  case homeLow = "home.low"
  case homeBluetoothOff = "home.btoff"
  case homeCut = "home.cut"
  case homeFirst = "home.first"
  case homeBusy = "home.busy"
  case homeDenied = "home.denied"
  case homeToken = "home.token"
  case homeFull = "home.full"
  case homeFirmware = "home.fw"
  case today
  case yesterday = "today.yesterday"
  case emptyDay = "today.empty"
  case conversationLive = "conv.live"
  case conversationSent = "conv.sent"
  case conversationCut = "conv.cut"
  case conversationTranscribing = "conv.transcribing"
  case settings
  case pagePendant = "page.pendant"
  case pagePendantOff = "page.pendant.off"
  case pageGestures = "page.gestures"
  case pageOffline = "page.offline"
  case pageNotifications = "page.notifications"
  case pageServer = "page.server"
  case pageControls = "page.controls"
  case pageControlsGuide = "page.controls.guide"
  case pageControlsPause = "page.controls.pause"
  case pageControlsOff = "page.controls.off"
  case pageAdvanced = "page.advanced"
  case pageInfo = "page.info"
  case pageLicenses = "page.licenses"
  case pageTheme = "page.theme"
  case obWelcome = "ob.welcome"
  case obBluetooth = "ob.bluetooth"
  case obDenied = "ob.denied"
  case obSearch = "ob.search"
  case obFound = "ob.found"
  case obLinked = "ob.linked"
  case obNone = "ob.none"
  case obServer = "ob.server"
  case obNotifications = "ob.notifications"
  case obDone = "ob.done"

  /// The fixed clock of every scene.
  var now: Date { Self.at(17, 42) }

  private static func at(_ hour: Int, _ minute: Int, day: Int = 26, second: Int = 0) -> Date {
    Calendar.current.date(
      from: DateComponents(
        year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
  }

  var tab: AppModel.Tab {
    switch self {
    case .today, .yesterday, .emptyDay, .conversationLive, .conversationSent, .conversationCut,
      .conversationTranscribing:
      .today
    case .settings, .pagePendant, .pagePendantOff, .pageGestures, .pageOffline, .pageNotifications,
      .pageServer, .pageControls, .pageControlsGuide, .pageControlsPause,
      .pageControlsOff, .pageAdvanced, .pageInfo, .pageLicenses,
      .pageTheme:
      .settings
    default: .now
    }
  }

  var settingsPath: [AppModel.Page] {
    switch self {
    case .pagePendant, .pagePendantOff: [.pendant]
    case .pageGestures: [.gestures]
    case .pageOffline: [.offline]
    case .pageNotifications: [.notifications]
    case .pageServer: [.server]
    case .pageControls, .pageControlsGuide, .pageControlsPause, .pageControlsOff:
      [.systemControls]
    case .pageAdvanced: [.advanced]
    case .pageInfo: [.info]
    case .pageLicenses: [.info, .licenses]
    case .pageTheme: [.theme]
    default: []
    }
  }

  /// The conversation pushed on Oggi.
  var todayPath: [UUID] {
    switch self {
    case .conversationLive: [Fixture.live]
    case .conversationSent: [Fixture.morning]
    case .conversationCut: [Fixture.cut]
    case .conversationTranscribing: [Fixture.latest]
    default: []
    }
  }

  /// Days back on Oggi.
  var dayOffset: Int {
    switch self {
    case .yesterday: 1
    case .emptyDay: 2
    default: 0
    }
  }

  var onboarding: AppModel.OnboardingStep? {
    switch self {
    case .obWelcome: .welcome
    case .obBluetooth: .bluetooth
    case .obDenied: .denied
    case .obSearch, .obFound, .obLinked, .obNone: .search
    case .obServer: .server
    case .obNotifications: .notifications
    case .obDone: .done
    default: nil
    }
  }

  /// The search state of the first launch.
  var search: SearchStateDemo {
    switch self {
    case .obFound: .found
    case .obLinked: .linked
    case .obNone: .none
    default: .scanning
    }
  }

  /// The search states, mirrored for scenes.
  enum SearchStateDemo { case scanning, found, linked, none }

  var config: Configuration { .defaults }

  var credentials: Credentials? {
    Credentials(
      url: URL(string: "wss://server.example.com/api/audio-stream/ws")!, token: "demo-7f3a")
  }

  var probeOutcome: ServerProbeOutcome { .ok }

  var snapshot: AppModel.Snapshot {
    let n = now
    var s = AppModel.Snapshot(
      mode: .recording, since: n.addingTimeInterval(-728), battery: 84,
      serverHost: "server.example.com", serverState: .online, level: -16.7, firmware: "3.0.21")
    switch self {
    case .homePause, .homeBusy, .pageControlsPause:
      s.mode = .paused
      s.since = n.addingTimeInterval(-130)
    case .homeOff, .pageControlsOff:
      s.mode = .disconnected
      s.since = n.addingTimeInterval(-182)
      s.battery = nil
    case .homeQueue:
      s.queuedSeconds = 120
      s.serverState = .unreachable
      s.serverFailingSince = n.addingTimeInterval(-150)
    case .homeCharge:
      s.battery = 62
      s.charging = true
    case .homeLow:
      s.battery = 12
      s.notice = .batteryLow
    case .homeBluetoothOff:
      s.mode = .bluetoothOff
      s.since = n.addingTimeInterval(-45)
      s.battery = nil
      s.notice = .bluetoothOff
    case .homeCut:
      s.mode = .disconnected
      s.since = n.addingTimeInterval(-48)
      s.battery = nil
      s.resumesUntil = n.addingTimeInterval(72)
    case .homeFirst:
      s.since = n.addingTimeInterval(-12)
    case .homeDenied:
      s.mode = .denied
      s.since = n.addingTimeInterval(-318)
      s.battery = nil
      s.notice = .bluetoothDenied
    case .homeToken:
      s.queuedSeconds = 180
      s.serverState = .tokenRejected
      s.serverFailingSince = Self.at(17, 39)
      s.notice = .tokenRejected
    case .homeFull:
      s.since = n.addingTimeInterval(-2468)
      s.queuedSeconds = 27 * 60
      s.serverState = .unreachable
      s.serverFailingSince = Self.at(17, 15)
      s.notice = .queueNearlyFull
    case .homeFirmware:
      s.firmware = "3.0.24"
      s.notice = .firmwareUnsupported
    default:
      break
    }
    return s
  }

  var device: AppModel.Device {
    let away: Set<DemoScene> = [
      .homeOff, .homeCut, .homeBluetoothOff, .homeDenied, .pagePendantOff, .pageControlsOff,
    ]
    if away.contains(self) {
      return AppModel.Device(connected: false, lastSeen: Self.at(17, 39))
    }
    return AppModel.Device(
      connected: true, battery: 84, firmware: "3.0.21", micGain: 6, pendingPackets: 53)
  }

  var conversations: ConversationLog {
    if self == .homeFirst { return ConversationLog(conversations: [Fixture.liveConversation(now)]) }
    if self == .homeBusy { return Fixture.log(now: now, busy: true) }
    return Fixture.log(now: now)
  }

  /// The conversations of the mock.
  enum Fixture {
    static let live = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let morning = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let cut = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let latest = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    /// The submission of a conversation whose transcript arrived.
    static var transcribed: Submission {
      var op = Submission(id: "demo-morning", url: nil)
      op.status = .done
      op.transcript = Transcript(
        language: "it", duration: 2892,
        segments: [
          .init(speaker: "0", text: "Allora, partiamo dal calendario delle consegne."),
          .init(speaker: "0", text: "La prima è fissata per il 12, giusto?"),
          .init(
            speaker: "1", text: "Sì, il 12. Ma la parte dei test la sposterei alla settimana dopo."
          ),
          .init(speaker: "0", text: "Va bene, allora la segno così e la riprendiamo lunedì."),
        ])
      return op
    }

    /// The submission of a conversation the server is still transcribing.
    static var transcribing: Submission {
      var op = Submission(id: "demo-latest", url: nil)
      op.status = .running
      op.checks = 1
      return op
    }

    static func liveConversation(_ now: Date) -> Conversation {
      Conversation(id: live, start: now.addingTimeInterval(-12))
    }

    /// The log of the mock; `busy` adds five conversations today, for a list longer than the
    /// home shows.
    static func log(now: Date, busy: Bool = false) -> ConversationLog {
      func c(
        _ h: Int, _ m: Int, seconds: Int, id: UUID = UUID(), day: Int = 26,
        status: Conversation.Status = .sent, marks: [(Int, Int)] = [],
        submission: Submission? = nil
      ) -> Conversation {
        let start = DemoScene.at(h, m, day: day)
        return Conversation(
          id: id, start: start, end: start.addingTimeInterval(Double(seconds)), status: status,
          bookmarks: marks.map { DemoScene.at($0.0, $0.1, day: day) }, submission: submission)
      }
      let extra =
        busy
        ? [
          c(16, 40, seconds: 724), c(15, 12, seconds: 1331, status: .interrupted),
          c(13, 5, seconds: 2461), c(10, 15, seconds: 1093), c(8, 40, seconds: 427),
        ] : []
      return ConversationLog(
        conversations: extra + [
          Conversation(
            id: live, start: DemoScene.at(17, 30), bookmarks: [DemoScene.at(17, 36)]),
          c(17, 21, seconds: 287, id: latest, submission: transcribing),
          c(
            11, 30, seconds: 2892, id: morning, marks: [(11, 42), (12, 5)], submission: transcribed),
          c(9, 4, seconds: 2586),
          c(18, 40, seconds: 552, day: 25),
          c(15, 12, seconds: 1331, id: cut, day: 25, status: .interrupted),
          c(10, 15, seconds: 4335, day: 25, marks: [(10, 48)]),
          c(8, 52, seconds: 1874, day: 25),
        ])
    }
  }
}
