import Foundation
import Security

/// The Nexus endpoint and token, kept in the iOS keychain.
///
/// They reach the iPhone without typing: `make credentials` copies a `bootstrap.json` into the
/// app's Documents folder, and the app moves it into the keychain at launch and deletes the
/// file, so the token never stays on disk in clear.
struct Credentials: Codable, Equatable {
  /// The `audio_stream` WebSocket URL, `wss://.../api/audio-stream/ws`.
  let url: URL
  /// The dedicated audio stream token.
  let token: String

  private static let service = "dev.esse.pendant.nexus"
  private static let account = "audio-stream"

  /// The saved credentials, if any.
  static func load() -> Credentials? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return try? JSONDecoder().decode(Credentials.self, from: data)
  }

  /// Saves these credentials, replacing any previous ones.
  ///
  /// Readable after the first unlock, so the app can reconnect in the background after a
  /// restart.
  func save() throws {
    let data = try JSONEncoder().encode(self)
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
    ]
    SecItemDelete(base as CFDictionary)
    var add = base
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(add as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  /// Moves `Documents/bootstrap.json` into the keychain; returns what happened, for the log.
  static func importBootstrap() -> String? {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let file = documents.appending(path: "bootstrap.json")
    guard FileManager.default.fileExists(atPath: file.path()) else { return nil }
    defer { try? FileManager.default.removeItem(at: file) }
    do {
      let credentials = try JSONDecoder().decode(Credentials.self, from: Data(contentsOf: file))
      guard credentials.url.scheme == "wss", !credentials.token.isEmpty else {
        return "rejected: the URL must be wss:// and the token not empty"
      }
      try credentials.save()
      return "saved for \(credentials.url.host() ?? "?")"
    } catch {
      return "failed: \(error.localizedDescription)"
    }
  }
}
