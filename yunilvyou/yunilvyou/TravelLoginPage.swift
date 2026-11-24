import SwiftUI

struct TravelLoginPage: View {
  @EnvironmentObject private var account: TravelAccount
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var carrier = CarrierAuthorization()
  @State private var phase: Phase = .consent
  @State private var agreed = true
  @State private var consentPrompt = false
  @State private var phone = ""
  @State private var code = ""
  @State private var challenge: WishChallenge?
  @State private var expires = Date.distantPast
  @State private var resend = Date.distantPast
  @State private var verifyAfter = Date.distantPast
  @State private var busy = false
  @State private var status = ""
  @State private var work: Task<Void, Never>?
  @FocusState private var focused: Field?
  private enum Phase { case consent, carrier, exchange, sms }
  private enum Field { case phone, code }

  var body: some View {
    ZStack {
      GeometryReader { screen in
        Image("login-beijing").resizable().scaledToFill()
          .frame(width: screen.size.width, height: screen.size.height)
          .clipped()
          .overlay(LinearGradient(colors: [.clear, .black.opacity(0.6)],
            startPoint: .center, endPoint: .bottom))
      }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)

      GeometryReader { screen in
        ScrollView {
          VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
              Text("予你旅行")
                .font(.custom(TravelTypography.face, size: 44, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)
              Text("从一个心愿出发，\n遇见属于你的风景。")
                .font(.travel(.title3)).lineSpacing(5)
            }
            .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 5, y: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28).padding(.top, 32)
            Spacer(minLength: 40)
            loginCard
              .frame(maxWidth: 350)
              .padding(.horizontal, 24)
            agreementFooter
              .padding(.top, 12)
              .frame(maxWidth: 430).padding(.horizontal, 16).padding(.bottom, 12)
          }
          .frame(maxWidth: .infinity, minHeight: screen.size.height)
          .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: consentPrompt)
        }.travelKeyboardDismissal()
      }
    }
    .onDisappear { if phase != .carrier { work?.cancel() } }
  }

  private var loginCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let message = account.logoutMessage { Text(message).font(.travel(.subheadline)) }
      if !WishbookService.available {
        Text("此版本暂时无法连接登录服务。")
      } else if phase == .consent {
        Button(action: beginCarrierLogin) {
          Text("同意并获取本机号码").font(.travel(.title2))
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 60).contentShape(Rectangle())
        }
          .buttonStyle(.borderedProminent).controlSize(.large)
          .accessibilityHint("同意用户服务协议和隐私政策后，开始运营商号码认证")
          .accessibilityIdentifier("login.consent")
      } else if phase == .sms {
        Text("短信验证码登录").font(.travel(.headline)).accessibilityAddTraits(.isHeader)
        TextField("11 位手机号", text: $phone).keyboardType(.phonePad)
          .textContentType(.telephoneNumber).focused($focused, equals: .phone).disabled(busy)
          .onChange(of: phone) { _ in challenge = nil; code = ""; status = "" }
          .padding(.horizontal, 12).frame(minHeight: 48).background(Ink.canvas, in: RoundedRectangle(cornerRadius: 12))
        TimelineView(.periodic(from: .now, by: 1)) { tick in
          let wait = seconds(until: resend, now: tick.date)
          Button(action: send) {
            HStack(spacing: 10) {
              if busy { ProgressView() }
              Text(busy ? "正在处理，请稍候…" : wait > 0 ? "\(wait) 秒后可重发" : "获取验证码")
            }
          }
            .buttonStyle(PanelActionStyle())
            .disabled(!agreed || busy || wait > 0 || !WishbookService.validPhone(phone))
            .accessibilityIdentifier("login.sendCode")
        }
        if challenge != nil {
          TextField("短信验证码", text: $code).keyboardType(.numberPad)
            .textContentType(.oneTimeCode).focused($focused, equals: .code).disabled(busy)
            .padding(.horizontal, 12).frame(minHeight: 48).background(Ink.canvas, in: RoundedRectangle(cornerRadius: 12))
          TimelineView(.periodic(from: .now, by: 1)) { tick in
            let wait = seconds(until: verifyAfter, now: tick.date)
            if expires <= tick.date { Text("验证码已过期，请重新获取。") }
            MainButton(wait > 0 ? "\(wait) 秒后可登录" : "登录") { verify() }
              .disabled(!agreed || busy || wait > 0 || tick.date >= expires || !WishbookService.validCode(code))
          }
        }
        if !status.isEmpty { Text(status).font(.travel(.subheadline)).accessibilityIdentifier("login.status") }
        Button("重新尝试本机号码登录", action: beginCarrierLogin)
          .frame(minHeight: 44).disabled(busy)
      } else {
        ProgressView(phase == .exchange ? "正在验证登录身份…" : "正在获取本机号码…")
      }
    }
    .foregroundStyle(Ink.text).frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Ink.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
  }

  private var agreementFooter: some View {
    VStack(alignment: .center, spacing: 0) {
      if consentPrompt {
        Text("请先阅读并同意协议，再继续登录。")
          .font(.travel(.footnote)).foregroundStyle(.white)
          .padding(.bottom, 4)
          .transition(.opacity)
      }
      HStack(spacing: 0) {
        Button {
          agreed.toggle()
          consentPrompt = false
        } label: {
          Image(systemName: agreed ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 23))
            .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("同意用户服务协议和隐私政策")
        .accessibilityValue(agreed ? "已同意" : "未同意")
        .accessibilityIdentifier("login.agree")
        AgreementLinks(horizontal: true).font(.travel(.footnote))
      }
      .buttonStyle(.plain).foregroundStyle(.white)
      .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
      .disabled(busy || phase == .carrier || phase == .exchange)
    }
  }

  private func beginCarrierLogin() {
    guard (phase == .consent || phase == .sms), !busy else { return }
    guard agreed else { consentPrompt = true; return }
    phase = .carrier
    carrier.start { token, message in
      guard let token else { showSMS(message); return }
      phase = .exchange
      work = Task {
        do {
          let login = try await account.service.login(carrierToken: token)
          try Task.checkCancellation()
          account.accept(login)
        } catch {
          if !Task.isCancelled { showSMS("本机号码登录未完成，可改用短信登录。\n" + loginMessage(error)) }
        }
      }
    }
  }

  private func seconds(until date: Date, now: Date) -> Int { max(0, Int(ceil(date.timeIntervalSince(now)))) }

  private func showSMS(_ message: String) {
    carrier.cancel()
    phase = .sms
    status = message
  }

  private func send() {
    guard agreed, !busy, resend <= Date(), WishbookService.validPhone(phone) else { return }
    run(sending: true) {
      let response = try await account.service.send(phone: phone)
      try Task.checkCancellation()
      challenge = response
      code = ""
      expires = Date().addingTimeInterval(TimeInterval(response.expiresInSeconds))
      resend = Date().addingTimeInterval(TimeInterval(response.resendAfterSeconds))
      status = "验证码已请求发送，请查看手机短信。"
      focused = .code
    }
  }

  private func verify() {
    guard agreed, !busy, let challenge, verifyAfter <= Date(), expires > Date(), WishbookService.validCode(code) else { return }
    run(sending: false) {
      let login = try await account.service.login(phone: phone, challenge: challenge, code: code)
      try Task.checkCancellation()
      account.accept(login)
    }
  }

  private func run(sending: Bool, action: @escaping @MainActor () async throws -> Void) {
    busy = true
    focused = nil
    status = sending ? "正在请求验证码…" : "正在登录…"
    work = Task {
      defer { busy = false }
      do { try await action() }
      catch {
        guard !Task.isCancelled else { return }
        status = loginMessage(error)
        if let issue = error as? WishServiceError, case let .rateLimited(seconds?, _) = issue {
          let until = Date().addingTimeInterval(TimeInterval(seconds))
          if sending { resend = until } else { verifyAfter = until }
        }
      }
    }
  }
}

private func loginMessage(_ error: Error) -> String {
  if let network = error as? URLError {
    switch network.code {
    case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .secureConnectionFailed:
      return "手机无法验证登录服务器的 HTTPS 证书。"
    case .timedOut: return "登录服务响应超时，请稍后再试。"
    case .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost:
      return "无法连接登录服务，请检查网络连接和系统中的本地网络权限。"
    default: break
    }
  }
  return error.localizedDescription
}

struct RestoreLoginPage: View {
  @EnvironmentObject private var account: TravelAccount
  @State private var status = ""
  @State private var attempt = 0

  var body: some View {
    TravelPage {
      Panel("恢复登录") {
        if status.isEmpty {
          ProgressView("正在恢复登录…")
        } else {
          Text(status)
          MainButton("重试") { status = ""; attempt += 1 }
          Button("重新登录") { account.expire() }
        }
      }
    }.task(id: attempt) {
      do { try await account.restore() }
      catch { if !Task.isCancelled { status = loginMessage(error) } }
    }
  }
}
