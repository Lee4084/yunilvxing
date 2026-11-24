import XCTest

extension XCUIApplication {
  @MainActor func launchSignedInForUITest() {
    #if targetEnvironment(simulator)
    launchArguments.append("-travelOfflineUITests")
    launch()
    buttons["login.consent"].tap()
    let phone = textFields["11 位手机号"]
    XCTAssertTrue(phone.waitForExistence(timeout: 8))
    phone.tap()
    phone.typeText("13800000001")
    buttons["login.sendCode"].tap()
    let code = textFields["短信验证码"]
    XCTAssertTrue(code.waitForExistence(timeout: 5))
    code.tap()
    code.typeText("123456")
    let login = buttons["登录"]
    if !login.isHittable { swipeUp() }
    login.tap()
    #else
    // Device navigation tests use an account already signed in by its owner.
    launch()
    #endif
    XCTAssertTrue(tabBars.buttons["灵感故事"].waitForExistence(timeout: 8))
  }
}

@MainActor final class LoginTests: XCTestCase {
  func testLogoutConfirmationAndReturnToLogin() throws {
    let app = XCUIApplication()
    app.launchSignedInForUITest()
    app.tabBars.buttons["我的"].tap()
    let logout = app.buttons["account.logout"]
    for _ in 0..<8 where !logout.isHittable { app.swipeUp() }
    XCTAssertTrue(logout.isHittable)
    logout.tap()
    app.buttons["取消"].tap()
    XCTAssertTrue(app.tabBars.buttons["我的"].isSelected)
    logout.tap()
    let confirm = app.buttons.matching(identifier: "退出登录").allElementsBoundByIndex.last
    XCTAssertNotNil(confirm)
    confirm?.tap()
    XCTAssertTrue(app.buttons["login.consent"].waitForExistence(timeout: 8))
    XCTAssertFalse(app.tabBars.buttons["我的"].exists)
  }

  func testSMSFallbackStartsWithNoMessageSent() throws {
    let app = XCUIApplication()
    #if targetEnvironment(simulator)
    app.launchArguments.append("-travelOfflineUITests")
    #endif
    app.launch()
    if app.tabBars.buttons["灵感故事"].exists { throw XCTSkip("此设备已有登录会话") }
    let consent = app.buttons["login.consent"]
    XCTAssertTrue(consent.waitForExistence(timeout: 6))
    XCTAssertTrue(consent.isHittable)
    let cover = XCTAttachment(screenshot: app.screenshot())
    cover.name = "全屏天安门登录页"
    cover.lifetime = .keepAlways
    add(cover)
    XCTAssertFalse(app.textFields["11 位手机号"].exists)
    for title in ["用户服务协议", "隐私政策"] {
      app.buttons[title].tap()
      XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
      XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
      app.buttons["完成"].tap()
      XCTAssertTrue(consent.waitForExistence(timeout: 5))
    }
    XCTAssertEqual(app.buttons["login.agree"].value as? String, "已同意")
    app.buttons["login.agree"].tap()
    consent.tap()
    XCTAssertTrue(consent.exists)
    XCTAssertFalse(app.textFields["11 位手机号"].exists)
    XCTAssertTrue(app.staticTexts["请先阅读并同意协议，再继续登录。"].exists)
    app.buttons["login.agree"].tap()
    consent.tap()
    let send = app.buttons["login.sendCode"]
    XCTAssertTrue(send.waitForExistence(timeout: 15))
    XCTAssertTrue(app.textFields["11 位手机号"].exists)
    XCTAssertFalse(consent.exists)
    let fallback = XCTAttachment(screenshot: app.screenshot())
    fallback.name = "取号失败后显示短信登录"
    fallback.lifetime = .keepAlways
    add(fallback)
    XCTAssertFalse(send.isEnabled)
    XCTAssertFalse(app.textFields["短信验证码"].exists)
  }
}
