import Foundation
import Combine
import Security

struct TravelSession: Codable {
  let login: WishLogin
  let issuedAt: Date

  func canUseAccess(at date: Date) -> Bool {
    issuedAt.addingTimeInterval(TimeInterval(login.accessTokenExpiresIn)) > date
  }

  func canRefresh(at date: Date) -> Bool {
    issuedAt.addingTimeInterval(TimeInterval(login.refreshTokenExpiresIn)) > date
  }
}

@MainActor final class TravelAccount: ObservableObject {
  @Published private(set) var session: TravelSession?
  @Published private(set) var restoring = false
  @Published private(set) var logoutMessage: String?
  private var generation = UUID()
  let service: WishbookService
  private let persistSession: Bool
  private var renewal: Task<WishLogin, Error>?
  private let key: [String: Any]

  init(service: WishbookService? = nil, persistSession: Bool = true) {
    self.persistSession = persistSession
    self.service = service ?? WishbookService()
    key = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "yunilvyou") + ".session",
      kSecAttrAccount as String: WishbookService.baseURL?.absoluteString ?? "unconfigured"]
    guard WishbookService.available, self.persistSession else { return }
    var query = key
    query[kSecReturnData as String] = true
    var result: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data, let saved = try? JSONDecoder().decode(TravelSession.self, from: data),
      saved.canUseAccess(at: Date()) || saved.canRefresh(at: Date()) {
      session = saved
      restoring = !saved.canUseAccess(at: Date())
    }
  }

  func accept(_ login: WishLogin) {
    logoutMessage = nil
    let saved = TravelSession(login: login, issuedAt: Date())
    if persistSession, let bytes = try? JSONEncoder().encode(saved) {
      let values: [String: Any] = [kSecValueData as String: bytes,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
      if SecItemUpdate(key as CFDictionary, values as CFDictionary) == errSecItemNotFound {
        let item = key.merging(values) { _, new in new }
        SecItemAdd(item as CFDictionary, nil)
      }
    }
    restoring = false
    session = saved
  }

  func restore() async throws {
    guard let original = session, restoring else { return }
    _ = try await renew(original)
  }

  func expire() {
    generation = UUID()
    renewal?.cancel()
    renewal = nil
    restoring = false
    if persistSession { SecItemDelete(key as CFDictionary) }
    session = nil
  }

  func logout() async throws {
    guard let original = session else { return }
    // Only return to the login screen once the stored credential has been removed.
    if persistSession {
      let status = SecItemDelete(key as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw NSError(domain: "TravelAccount", code: Int(status),
          userInfo: [NSLocalizedDescriptionKey: "暂时无法清除登录凭证，请解锁设备后重试。"])
      }
    }
    let pending = renewal
    expire()
    let signedOutGeneration = generation
    var revoked = true
    do { try await service.logout(original.login) }
    catch { revoked = false }
    if let refreshed = try? await pending?.value,
      refreshed.accessToken != original.login.accessToken {
      do { try await service.logout(refreshed) }
      catch { revoked = false }
    }
    guard generation == signedOutGeneration, session == nil else { return }
    logoutMessage = revoked ? "已退出登录。" : "已退出本机登录。网络异常，服务端会话撤销尚未确认。"
  }

  private func renew(_ original: TravelSession) async throws -> WishLogin {
    if let renewal {
      let startedGeneration = generation
      let renewed = try await renewal.value
      guard generation == startedGeneration else { throw CancellationError() }
      return renewed
    }
    if let current = session, current.login.appUser.id == original.login.appUser.id,
      current.login.accessToken != original.login.accessToken, current.canUseAccess(at: Date()) {
      return current.login
    }
    guard original.canRefresh(at: Date()) else {
      expire()
      throw WishServiceError.http(status: 401, code: nil, requestID: nil)
    }
    let startedGeneration = generation
    let job = Task<WishLogin, Error> {
      defer { if generation == startedGeneration { renewal = nil } }
      do {
        let renewed = try await service.refresh(original.login)
        if generation == startedGeneration { accept(renewed) }
        return renewed
      } catch let error as WishServiceError {
        switch error {
        case .http(401, _, _), .http(403, _, _):
          if generation == startedGeneration { expire() }
        default: break
        }
        throw error
      }
    }
    renewal = job
    let refreshed = try await job.value
    guard generation == startedGeneration else { throw CancellationError() }
    return refreshed
  }

  func submit(draftID: UUID, text: String) async throws -> WishAcknowledgement {
    guard let original = session else { throw WishServiceError.unavailable }
    if original.canUseAccess(at: Date()) {
      do { return try await service.submit(draftID: draftID, text: text, login: original.login) }
      catch WishServiceError.http(401, _, _) { /* Refresh once using the same account and draft. */ }
    }
    let login = try await renew(original)
    do { return try await service.submit(draftID: draftID, text: text, login: login) }
    catch let error as WishServiceError {
      if case .http(401, _, _) = error { expire() }
      throw error
    }
  }
}
