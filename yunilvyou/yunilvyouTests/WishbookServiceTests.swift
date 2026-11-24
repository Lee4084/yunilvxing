import Foundation
import XCTest
@testable import yunilvyou

@MainActor final class WishbookServiceTests: XCTestCase {
  private func service() -> WishbookService {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [WishProtocol.self]
    return WishbookService(session: URLSession(configuration: config))
  }

  func testLogoutAcceptsEmptyResponseAndAlreadyExpiredSession() async throws {
    let api = service()
    let login = try await api.login(carrierToken: "carrier-proof")
    try await api.logout(login)
    let expired = WishLogin(accessTokenExpiresIn: 0, refreshToken: login.refreshToken,
      refreshTokenExpiresIn: 600, accessToken: "expired", appUser: login.appUser)
    try await api.logout(expired)
  }

  func testLogoutClearsLocalSessionEvenWhenOffline() async throws {
    let api = service()
    let login = try await api.login(carrierToken: "carrier-proof")
    let account = TravelAccount(service: api, persistSession: false)
    account.accept(WishLogin(accessTokenExpiresIn: 120, refreshToken: login.refreshToken,
      refreshTokenExpiresIn: 600, accessToken: "offline", appUser: login.appUser))
    try await account.logout()
    XCTAssertNil(account.session)
    XCTAssertFalse(account.restoring)
    XCTAssertNotNil(account.logoutMessage)
  }

  func testLogoutReturnsToLoginAndCanSignInAgain() async throws {
    let api = service()
    let login = try await api.login(carrierToken: "carrier-proof")
    let account = TravelAccount(service: api, persistSession: false)
    account.accept(login)
    try await account.logout()
    XCTAssertNil(account.session)
    account.accept(login)
    XCTAssertNotNil(account.session)
    XCTAssertNil(account.logoutMessage)
  }

  func testValidation() {
    for value in ["00000000000", "DEMO-0001", "13800000001\n", "１３８０００００００１"] {
      XCTAssertFalse(WishbookService.validPhone(value))
    }
    XCTAssertFalse(WishbookService.validCode("12ab56"))
    XCTAssertTrue(WishbookService.validCode("012345"))
  }

  func testAcceptedSubmissionAndRetry() async throws {
    let api = service()
    let challenge = try await api.send(phone: "13800000001")
    XCTAssertEqual(challenge.resendAfterSeconds, 60)
    let login = try await api.login(phone: "13800000001", challenge: challenge, code: "123456")
    let draft = UUID()
    let first = try await api.submit(draftID: draft, text: "测试愿望", login: login)
    let retry = try await api.submit(draftID: draft, text: "测试愿望", login: login)
    let other = try await api.submit(draftID: UUID(), text: "测试愿望", login: login)
    XCTAssertEqual(first.submissionId, retry.submissionId)
    XCTAssertNotEqual(first.submissionId, other.submissionId)
  }

  func testCarrierLoginAndRenewedSessionCanSubmitWithoutSMS() async throws {
    let api = service()
    let login = try await api.login(carrierToken: "carrier-proof")
    XCTAssertEqual(login.appUser.maskedPhone, "138****0001")
    let renewed = try await api.refresh(login)
    XCTAssertEqual(renewed.appUser.id, login.appUser.id)
    _ = try await api.submit(draftID: UUID(), text: "测试愿望", login: renewed)
  }

  func testEmptyCarrierProofIsRejectedBeforeSending() async throws {
    do {
      _ = try await service().login(carrierToken: "")
      XCTFail("Expected invalid proof")
    } catch WishServiceError.invalidResponse {}
  }

  func testEntryIdentityIsReusedWhenSubmittingAndRefreshedAfter401() async throws {
    let api = service()
    let login = try await api.login(carrierToken: "carrier-proof")
    let account = TravelAccount(service: api, persistSession: false)
    XCTAssertNil(account.session)
    let stale = WishLogin(accessTokenExpiresIn: 100, refreshToken: login.refreshToken,
      refreshTokenExpiresIn: 600, accessToken: "expired", appUser: login.appUser)
    account.accept(stale)
    _ = try await account.submit(draftID: UUID(), text: "测试愿望")
    XCTAssertEqual(account.session?.login.accessToken, login.accessToken)
  }

  func testRejectedRenewalReturnsToLogin() async throws {
    let api = service()
    let login = try await api.login(carrierToken: "carrier-proof")
    let account = TravelAccount(service: api, persistSession: false)
    account.accept(WishLogin(accessTokenExpiresIn: 0, refreshToken: "revoked",
      refreshTokenExpiresIn: 600, accessToken: "expired", appUser: login.appUser))
    do {
      _ = try await account.submit(draftID: UUID(), text: "测试愿望")
      XCTFail("Expected login to be required")
    } catch WishServiceError.http(401, _, _) { XCTAssertNil(account.session) }
  }

  func testRateLimitWithoutHeader() async throws {
    let api = service()
    for (phone, expected) in [("13800000003", nil as Int?), ("13800000004", 75)] {
      do {
        _ = try await api.send(phone: phone)
        XCTFail("Expected rate limiting")
      } catch WishServiceError.rateLimited(let seconds, let id) {
        XCTAssertEqual(seconds, expected)
        XCTAssertEqual(id, UUID(uuidString: "c2b9482b-1ef2-43e7-a847-b677efcc9b03"))
      }
    }
  }

  func testRetryAfterDateAndMalformedValues() {
    XCTAssertEqual(WishbookService.retryDelay(from: "Thu, 01 Jan 1970 00:00:30 GMT",
      relativeTo: Date(timeIntervalSince1970: 0)), 30)
    XCTAssertNil(WishbookService.retryDelay(from: "-1"))
    XCTAssertNil(WishbookService.retryDelay(from: "unknown"))
  }

  func testServerFailureShowsOnlySafeDiagnostics() async throws {
    let api = service()
    for (phone, expected) in [("13800000005", 503), ("13800000006", 502)] {
      do {
        _ = try await api.send(phone: phone)
        XCTFail("Expected failure")
      } catch let error as WishServiceError {
        let text = error.localizedDescription
        XCTAssertTrue(text.contains("HTTP \(expected)"))
        XCTAssertFalse(text.contains("private"))
        XCTAssertEqual(text.contains("SMS_UNAVAILABLE"), expected == 503)
        XCTAssertEqual(text.contains("c2b9482b-1ef2-43e7-a847-b677efcc9b03"), expected == 503)
      }
    }
  }

  func testRateLimitAndInvalidCode() async throws {
    let api = service()
    do {
      _ = try await api.send(phone: "13800000002")
      XCTFail("Expected rate limiting")
    } catch WishServiceError.rateLimited(let seconds, _) { XCTAssertEqual(seconds, 42) }
    let challenge = try await api.send(phone: "13800000001")
    do {
      _ = try await api.login(phone: "13800000001", challenge: challenge, code: "666666")
      XCTFail("Expected rejection")
    } catch WishServiceError.http(401, _, _) {}
  }
}
