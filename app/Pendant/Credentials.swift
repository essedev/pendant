import Foundation
import Security

/// The server endpoint and token, kept in the iOS keychain.
///
/// They are typed in the first launch or in the Server page. For development they can also
/// reach the iPhone without typing: `make credentials` copies a `bootstrap.json` into the app's
/// Documents folder, and the app moves it into the keychain at launch and deletes the file, so
/// the token never stays on disk in clear.
struct Credentials: Codable, Equatable {
  /// The `audio_stream` WebSocket URL, `wss://.../api/audio-stream/ws`.
  let url: URL
  /// The dedicated audio stream token.
  let token: String

  // The service name predates the server-agnostic app; renaming it would lose saved tokens.
  private static let service = "dev.esse.pendant.nexus"
  private static let account = "audio-stream"

  /// The path of `audio_stream` on a server, part of the protocol like the message types.
  static let streamPath = "/api/audio-stream/ws"

  /// The host shown in the app.
  var host: String { url.host() ?? url.absoluteString }

  /// The server's HTTP base, `https://host[:port]`, for the reads beside the stream.
  var httpBase: URL? {
    var components = URLComponents()
    components.scheme = url.scheme == "ws" ? "http" : "https"
    components.host = url.host()
    components.port = url.port
    return components.url
  }

  /// A read of the server with the same token as the stream, in the header.
  func get(_ url: URL, timeout: TimeInterval) -> URLRequest {
    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  /// The last four characters of the token, the only part the app shows.
  var tokenTail: String { String(token.suffix(4)) }

  /// The WebSocket URL for what the user typed: a bare host gets `wss://` and the protocol
  /// path; a full `wss://` URL is kept as it is. Nil when it cannot be a server address.
  static func url(fromAddress address: String) -> URL? {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
    if trimmed.hasPrefix("wss://") {
      guard let url = URL(string: trimmed), url.host() != nil else { return nil }
      return url
    }
    let host =
      trimmed.replacingOccurrences(of: "https://", with: "")
      .split(separator: "/").first.map(String.init) ?? ""
    guard !host.isEmpty, let url = URL(string: "wss://\(host)\(streamPath)"), url.host() != nil
    else { return nil }
    return url
  }

  /// The upgrade request of a conversation, with the token in the header.
  func request(language: String) -> URLRequest {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    if !language.isEmpty {
      components?.queryItems = [URLQueryItem(name: "language", value: language)]
    }
    var request = URLRequest(url: components?.url ?? url)
    // The header keeps the token out of URLs, which proxies log.
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
  }

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
