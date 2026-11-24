#if WISH_TESTS || (DEBUG && targetEnvironment(simulator)) || os(macOS)
import Foundation

final class WishProtocol: URLProtocol, @unchecked Sendable {
  nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
  nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  nonisolated override func stopLoading() {}

  nonisolated override func startLoading() {
    let url = request.url!
    let id = "c2b9482b-1ef2-43e7-a847-b677efcc9b03"
    var status = 200
    var result: [String: Any] = [:]
    let authentication: [String: Any] = ["accessToken": "test-token", "accessTokenExpiresIn": 120,
      "refreshToken": "test-refresh", "refreshTokenExpiresIn": 600, "appUser": ["id": id, "maskedPhone": "138****0001"]]
    var bytes = request.httpBody
    if bytes == nil, let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var collected = Data()
      var buffer = [UInt8](repeating: 0, count: 2048)
      while true {
        let n = stream.read(&buffer, maxLength: buffer.count)
        if n <= 0 { break }
        collected.append(contentsOf: buffer.prefix(n))
      }
      bytes = collected
    }
    let body = (bytes.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any]
    let path = url.path
    let testService = (url.host == "192.168.6.44" && url.port == 19443) || url.host == "fixture.invalid"
    if url.scheme != "https" || !testService
      || request.httpMethod != "POST" || request.value(forHTTPHeaderField: "X-App-Key") != "yunilvxing-ios" {
      status = 400
    } else if path == "/api/v1/auth/logout" {
      if request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token" { status = 204 }
      else if request.value(forHTTPHeaderField: "Authorization") == "Bearer offline" {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        return
      } else { status = 401 }
    } else if path == "/api/v1/auth/sms/send" {
      if body?["phone"] as? String == "13800000001" {
        result = ["challengeId": id, "expiresInSeconds": 300, "resendAfterSeconds": 60]
      } else if body?["phone"] as? String == "13800000005" {
        status = 503
      } else if body?["phone"] as? String == "13800000006" {
        status = 502
      } else { status = 429 }
    } else if path == "/api/v1/auth/sms/login" {
      if body?["code"] as? String == "123456", body?["challengeId"] as? String == id,
        body?["phone"] as? String == "13800000001" {
        result = authentication
      } else { status = 401 }
    } else if path == "/api/v1/auth/one-click/login", body as? [String: String] == ["accessToken": "carrier-proof"] {
      result = authentication
    } else if path == "/api/v1/auth/token/refresh", body as? [String: String] == ["refreshToken": "test-refresh"] {
      result = authentication
    } else if path == "/api/v1/auth/token/refresh" || request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
      status = 401
    } else if path == "/api/v1/forms/travel-wishbook/submissions",
      body?["formVersion"] as? Int == 1,
      let values = body?["values"] as? [String: String], (url.host == "fixture.invalid" ? values["wishbook"]?.isEmpty == false : values == ["wishbook": "测试愿望"]),
      request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token",
      let key = request.value(forHTTPHeaderField: "Idempotency-Key"), key.count == 64 {
      status = 201
      // A deterministic fixture makes duplicate retry keys observable through the returned receipt.
      let receipt = String(key.prefix(8)) + String(id.dropFirst(8))
      result = ["submissionId": receipt, "submittedAt": "2026-11-23T10:00:00Z"]
    } else { status = 400 }
    let hasHeader = body?["phone"] as? String != "13800000003" && body?["phone"] as? String != "13800000004"
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
      headerFields: hasHeader ? ["Retry-After": "42"] : [:])!
    var envelope: [String: Any] = ["data": result]
    if status == 429 {
      envelope = ["requestId": id, "code": "RATE_LIMITED"]
      if body?["phone"] as? String == "13800000004" { envelope["retryAfterSeconds"] = 75 }
    }
    if status == 503 {
      envelope = ["code": "SMS_UNAVAILABLE", "requestId": id, "message": "private upstream details"]
    } else if status == 502 {
      envelope = ["code": "private details: test", "requestId": "private details: test"]
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if status != 204 { client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: envelope)) }
    client?.urlProtocolDidFinishLoading(self)
  }
}
#endif
