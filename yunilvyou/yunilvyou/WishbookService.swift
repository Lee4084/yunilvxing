import CryptoKit
import Foundation

struct WishChallenge: Decodable {
  let challengeId: UUID
  let expiresInSeconds: Int
  let resendAfterSeconds: Int
}

struct WishLogin: Codable {
  struct User: Codable {
    let id: UUID
    let maskedPhone: String?
  }
  let accessTokenExpiresIn: Int
  let refreshToken: String
  let refreshTokenExpiresIn: Int
  let accessToken: String
  let appUser: User
}

struct WishAcknowledgement: Decodable {
  let submissionId: UUID
  let submittedAt: String
}

struct WishReceipt: Codable, Identifiable {
  let id: UUID
  let name: String
  let submittedAt: String
}

private struct WishEnvelope<Value: Decodable>: Decodable { let data: Value }

enum WishServiceError: LocalizedError {
  case unavailable, invalidResponse, invalidPhone, invalidCode
  case http(status: Int, code: String?, requestID: String?)
  case rateLimited(seconds: Int?, requestID: UUID?)

  var errorDescription: String? {
    switch self {
    case .unavailable: return "当前版本尚未配置愿望单服务。"
    case .invalidResponse: return "服务返回的结果不完整，请稍后重试。"
    case .invalidPhone: return "请输入 11 位中国大陆手机号。"
    case .invalidCode: return "请输入短信中的验证码。"
    case let .rateLimited(seconds, requestID):
      let guidance: String
      if let seconds, seconds > 0 {
        guidance = "服务已限流，请等按钮上的倒计时结束后再试。"
      } else if seconds == 0 {
        guidance = "服务暂时限制了这项操作。请稍后手动重试。"
      } else {
        guidance = "服务已限流，未返回可用的重试时间。请先暂停发送。"
      }
      guard let requestID else { return guidance }
      return guidance + "\n请求编号 " + requestID.uuidString.lowercased()
    case let .http(status, code, requestID):
      let guidance: String
      switch status {
      case 401 where code?.hasPrefix("SMS_") == true: guidance = "验证码错误或已过期，请核对短信或重新获取。"
      case 401: guidance = "当前登录凭证已失效，请重新登录。"
      case 403: guidance = "当前账号暂时无法使用这项服务。"
      case 404, 409: guidance = "服务或愿望单暂不可用。"
      case 400, 422: guidance = "服务未接受本次信息，请核对后重试。"
      case 502: guidance = "网关未取得有效的上游响应。"
      case 503: guidance = "服务当前不可用。"
      case 504: guidance = "网关等待上游响应超时。"
      case 500...599: guidance = "服务处理请求时发生错误。"
      default: guidance = "服务返回了未预期的状态。"
      }
      var lines = [guidance, "HTTP \(status)"]
      if let code { lines.append("服务错误码 " + code) }
      if let requestID { lines.append("请求编号 " + requestID) }
      return lines.joined(separator: "\n")
    }
  }
}

struct WishbookService {
  static let baseURL: URL? = TravelLoginConfiguration.apiBaseURL
  static var available: Bool { baseURL != nil }
  private static let connection: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.httpShouldSetCookies = false
    config.urlCache = nil
    config.timeoutIntervalForRequest = 18
    config.timeoutIntervalForResource = 30
    return URLSession(configuration: config)
  }()
  private let session: URLSession
  init(session: URLSession? = nil) { self.session = session ?? Self.connection }

  static func validPhone(_ phone: String) -> Bool {
    phone.utf8.count == 11 && phone.range(of: #"^1[3-9][0-9]{9}$"#, options: .regularExpression) != nil
  }
  static func validCode(_ code: String) -> Bool {
    (4...8).contains(code.utf8.count) && code.utf8.allSatisfy { (48...57).contains($0) }
  }

  func send(phone: String) async throws -> WishChallenge {
    guard Self.validPhone(phone) else { throw WishServiceError.invalidPhone }
    let result: WishChallenge = try await post("auth/sms/send", body: ["phone": phone])
    guard (1...86400).contains(result.expiresInSeconds),
      (0...86400).contains(result.resendAfterSeconds) else { throw WishServiceError.invalidResponse }
    return result
  }
  func login(phone: String, challenge: WishChallenge, code: String) async throws -> WishLogin {
    guard Self.validPhone(phone) else { throw WishServiceError.invalidPhone }
    guard Self.validCode(code) else { throw WishServiceError.invalidCode }
    return try await authenticated("auth/sms/login", body: [
      "phone": phone, "challengeId": challenge.challengeId.uuidString.lowercased(), "code": code
    ])
  }
  func login(carrierToken: String) async throws -> WishLogin {
    guard !carrierToken.isEmpty, carrierToken.utf8.count <= 8192 else { throw WishServiceError.invalidResponse }
    return try await authenticated("auth/one-click/login", body: ["accessToken": carrierToken])
  }

  func refresh(_ login: WishLogin) async throws -> WishLogin {
    let renewed = try await authenticated("auth/token/refresh", body: ["refreshToken": login.refreshToken])
    guard renewed.appUser.id == login.appUser.id else { throw WishServiceError.invalidResponse }
    return renewed
  }

  private func authenticated(_ path: String, body: [String: String]) async throws -> WishLogin {
    let login: WishLogin = try await post(path, body: body)
    guard !login.accessToken.isEmpty, !login.refreshToken.isEmpty,
      login.accessTokenExpiresIn > 0, login.refreshTokenExpiresIn > 0 else { throw WishServiceError.invalidResponse }
    return login
  }

  func submit(draftID: UUID, text: String, login: WishLogin) async throws -> WishAcknowledgement {
    // Same account, draft and content retain the key after a timeout or app restart.
    let identity = "travel-wishbook/v1/\(login.appUser.id)/\(draftID)/\(text)"
    let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    return try await post("forms/travel-wishbook/submissions",
      body: ["formVersion": 1, "values": ["wishbook": text]],
      token: login.accessToken, key: key)
  }

  static func retryDelay(from header: String?, relativeTo now: Date = Date()) -> Int? {
    guard let value = header?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    if value.utf8.allSatisfy({ (48...57).contains($0) }) {
      // Bound conversion to an interval the UI can represent without overflow.
      return Int32(value).map(Int.init)
    }
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(secondsFromGMT: 0)
    parser.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    guard let deadline = parser.date(from: value) else { return nil }
    return max(0, Int(ceil(deadline.timeIntervalSince(now))))
  }

  private func post<Value: Decodable>(_ path: String, body: [String: Any],
    token: String? = nil, key: String? = nil) async throws -> Value {
    let data = try await perform(path, body: body, token: token, key: key)
    guard let envelope = try? JSONDecoder().decode(WishEnvelope<Value>.self, from: data) else {
      throw WishServiceError.invalidResponse
    }
    return envelope.data
  }

  func logout(_ login: WishLogin) async throws {
    do { _ = try await perform("auth/logout", body: [:], token: login.accessToken) }
    catch WishServiceError.http(401, _, _) { /* The session is already invalid. */ }
  }

  private func perform(_ path: String, body: [String: Any], token: String? = nil, key: String? = nil) async throws -> Data {
    guard let base = Self.baseURL else { throw WishServiceError.unavailable }
    var request = URLRequest(url: base.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(TravelLoginConfiguration.appKey, forHTTPHeaderField: "X-App-Key")
    if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
    if let key { request.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw WishServiceError.invalidResponse }
    guard [200, 201, 204].contains(http.statusCode) else {
      let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      let detail = error?["error"] as? [String: Any]
      // The upstream message/body may contain SMS provider details or personal data.
      // Only surface a symbolic code and a recognizable correlation ID.
      let rawCode = detail?["code"] as? String ?? error?["code"] as? String
      let code = rawCode.flatMap { value -> String? in
        guard (2...64).contains(value.utf8.count),
          value.utf8.allSatisfy({ (65...90).contains($0) || $0 == 95 }) else { return nil }
        return value
      }
      let references = [error?["requestId"] as? String, http.value(forHTTPHeaderField: "X-Request-Id")]
      let reference = references.compactMap { $0 }.first { value in
        UUID(uuidString: value) != nil ||
          (value.utf8.count == 32 && value.utf8.allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
      }
      if http.statusCode == 429 {
        let rawSeconds = detail?["retryAfterSeconds"] ?? error?["retryAfterSeconds"]
        let bodySeconds = rawSeconds.flatMap { raw -> Int? in
          let value = String(describing: raw)
          guard value.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
          return Int32(value).map(Int.init)
        }
        let wait = Self.retryDelay(from: http.value(forHTTPHeaderField: "Retry-After")) ?? bodySeconds
        throw WishServiceError.rateLimited(seconds: wait, requestID: reference.flatMap(UUID.init(uuidString:)))
      }
      throw WishServiceError.http(status: http.statusCode, code: code, requestID: reference)
    }
    return data
  }
}
