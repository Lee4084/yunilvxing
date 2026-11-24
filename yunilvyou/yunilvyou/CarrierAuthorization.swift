import Combine
import UIKit
import ATAuthSDK

@MainActor final class CarrierAuthorization: ObservableObject {
  private var attempt: UUID?
  private var timeout: Task<Void, Never>?
  private var presenting = false
  private lazy var sdk = TXCommonHandler.sharedInstance()

  private var presenter: UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let active = scenes.filter { $0.activationState == .foregroundActive }
    var top = active.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
    while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
    return top
  }

  func start(finish: @escaping (String?, String) -> Void) {
    guard attempt == nil else { return }
    guard WishbookService.available else {
      finish(nil, "登录服务暂不可用，请稍后重试。")
      return
    }
    guard let info = TravelLoginConfiguration.values["SDKInfo"],
      !info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      finish(nil, "本机号码登录暂不可用，请使用短信验证码登录。")
      return
    }
    guard let type = PNSAuthType(rawValue: 2), let presenter,
      presenter.viewIfLoaded?.window != nil else {
      finish(nil, "暂时无法打开本机号码授权页，请使用短信验证码登录。")
      return
    }
    let id = UUID()
    attempt = id
    func complete(_ token: String? = nil, _ message: String = "未能获取本机号码，请使用短信验证码登录。") {
      guard attempt == id else { return }
      cancel()
      finish(token, message)
    }
    func armTimeout() {
      timeout?.cancel()
      timeout = Task {
        do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
        complete()
      }
    }
    armTimeout()
    sdk.getReporter().setConsolePrintLoggerEnable(false)
    sdk.setAuthSDKInfo(info) { [weak self] result in
      guard let self, self.attempt == id else { return }

      guard result["resultCode"] as? String == "600000" else { complete(); return }
      self.sdk.checkEnvAvailable(with: type) { result in
        guard self.attempt == id else { return }

        guard let code = result?["resultCode"] as? String, ["600000", "600024"].contains(code),
          presenter.viewIfLoaded?.window != nil else { complete(); return }
        let model = Self.bottomSheet(bottomInset: presenter.view.safeAreaInsets.bottom)
        model.checkBoxIsChecked = true
        model.privacyAlertIsNeedShow = true
        model.changeBtnIsHidden = false
        model.changeBtnTitle = NSAttributedString(string: "使用短信验证码登录")
        self.presenting = true
        // getLoginToken also prefetches the masked number before presenting the consent UI.
        self.sdk.getLoginToken(withTimeout: 5, controller: presenter, model: model) { event in
          guard self.attempt == id else { return }

          switch event["resultCode"] as? String {
          case "600000":
            guard let token = event["token"] as? String, !token.isEmpty else { complete(); return }
            complete(token, "")
          case "600001", "700003", "700004", "700006", "700007", "700009":
            self.timeout?.cancel() // Reading terms or choosing a SIM should not time out.
          case "700002":
            if (event["isChecked"] as? NSNumber)?.boolValue == true { armTimeout() }
          case "700008": armTimeout()
          case "600007":
            complete(nil, "未检测到可用的 SIM 卡，请检查 SIM 卡状态，或使用短信登录。")
          case "600008":
            complete(nil, "本机号码认证需要稳定的蜂窝数据。请开启当前 SIM 卡的蜂窝数据后重试，或使用短信登录。")
          case "700000", "700001", "700010", "700020": complete(nil, "")
          default: complete()
          }
        }
      }
    }
  }

  private static func bottomSheet(bottomInset: CGFloat) -> TXCustomModel {
    let model = TXCustomModel()
    let scale = UIFontMetrics(forTextStyle: .body).scaledValue(for: 1)
    model.contentViewFrameBlock = { screen, _, _ in
      let height = min(screen.height, 440 * min(scale, 1.3) + bottomInset)
      return CGRect(x: 0, y: screen.height - height, width: screen.width, height: height)
    }
    model.presentDirection = .bottom
    model.animationDuration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.25
    model.navIsHidden = true
    model.alertBarIsHidden = false
    model.alertTitle = NSAttributedString(string: "本机号码登录",
      attributes: [.font: UIFont.preferredFont(forTextStyle: .headline),
        .foregroundColor: UIColor.label])
    model.alertTitleBarColor = .secondarySystemBackground
    model.alertContentViewColor = .secondarySystemBackground
    model.backgroundColor = .secondarySystemBackground
    model.alertCornerRadiusArray = [24, 0, 0, 24]
    model.alertCloseItemIsHidden = false
    model.tapAuthPageMaskClosePage = true
    model.logoIsHidden = true
    model.numberColor = .label
    model.numberFont = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 26))
    model.numberFrameBlock = { _, parent, original in
      CGRect(x: (parent.width - original.width) / 2, y: 64,
        width: original.width, height: max(36, original.height))
    }
    model.sloganFrameBlock = { _, parent, original in
      CGRect(x: (parent.width - original.width) / 2, y: 116,
        width: original.width, height: max(24, original.height))
    }
    model.loginBtnFrameBlock = { _, parent, _ in
      CGRect(x: 24, y: 160, width: max(0, parent.width - 48), height: 56)
    }
    model.changeBtnFrameBlock = { _, parent, _ in
      CGRect(x: 24, y: 226, width: max(0, parent.width - 48), height: 48)
    }
    model.privacyFont = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 14))
    model.privacyColors = [UIColor.secondaryLabel, UIColor.systemRed]
    model.privacyFrameBlock = { _, parent, _ in
      CGRect(x: 24, y: 290, width: max(0, parent.width - 48),
        height: max(44, parent.height - 290 - bottomInset - 12))
    }
    return model
  }

  func cancel() {
    attempt = nil
    timeout?.cancel()
    timeout = nil
    if presenting {
      presenting = false
      sdk.cancelLoginVC(animated: false, complete: nil)
    }
  }
}
