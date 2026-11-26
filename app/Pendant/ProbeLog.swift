import Foundation
import OSLog
import Observation
import PendantKit

/// The verification log: recent entries for the screen, every entry appended to
/// `Documents/probe.jsonl` so `make logs` can copy it from the iPhone.
@MainActor @Observable
final class ProbeLog {
  /// The most recent entries, newest last.
  private(set) var entries: [ProbeEvent] = []

  private let screenLimit: Int
  /// The log file in Documents.
  let fileURL: URL
  private let logger = Logger(subsystem: "dev.esse.pendant", category: "probe")

  /// A log keeping `screenLimit` entries in memory.
  init(screenLimit: Int) {
    self.screenLimit = screenLimit
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    fileURL = documents.appending(path: "probe.jsonl")
  }

  /// Records an event on screen, in the system log and in the file.
  func record(_ kind: String, _ detail: String = "") {
    let event = ProbeEvent(kind: kind, detail: detail)
    logger.info("\(kind, privacy: .public) \(detail, privacy: .public)")
    entries.append(event)
    if entries.count > screenLimit { entries.removeFirst(entries.count - screenLimit) }
    do {
      try append(event.jsonLine())
    } catch {
      logger.error("log write failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func append(_ line: Data) throws {
    if !FileManager.default.fileExists(atPath: fileURL.path()) {
      try Data().write(to: fileURL)
    }
    let handle = try FileHandle(forWritingTo: fileURL)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: line)
  }
}
