import XCTest

@MainActor final class WishbookFlowTests: XCTestCase {
  private let app = XCUIApplication()

  override func setUpWithError() throws { continueAfterFailure = false }

  private func tap(_ element: XCUIElement) {
    for _ in 0..<7 {
      if element.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
    element.tap()
  }

  func testSpecialDayStoryAndPersonalPreferences() {
    app.launchSignedInForUITest()
    app.buttons["探索旅行灵感"].tap()
    tap(app.buttons["theme.0"])
    tap(app.buttons["discovery.YN-S01"])
    XCTAssertTrue(app.navigationBars["故事详情"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.firstMatch.tap()
    app.navigationBars.buttons.firstMatch.tap()
    app.tabBars.buttons["我的"].tap()
    XCTAssertTrue(app.staticTexts["我的心愿书"].exists)
    tap(app.buttons["希望如何联系你"])
    app.buttons["短信联系"].tap()
    XCTAssertEqual(app.buttons["希望如何联系你"].value as? String, "短信联系")
  }

  func testIOS15WishbookUsesLoginForSubmission() {
    app.launchArguments.append("-testIOS15Interaction")
    verifyCompletedWishbookSubmission()
  }

  func testWishbookUsesLoginForSubmission() {
    verifyCompletedWishbookSubmission()
  }

  private func verifyCompletedWishbookSubmission() {
    app.launchSignedInForUITest()
    app.tabBars.buttons["设计旅行"].tap()
    tap(app.buttons["新建一段旅行"])
    tap(app.buttons["为自己"])
    tap(app.buttons["下一章"])
    tap(app.buttons["生日"])
    tap(app.buttons["下一章"])
    tap(app.buttons["把生日留给一片海"])
    tap(app.buttons["海边散步"])
    app.swipeDown()
    tap(app.buttons["暂不区分优先级"])
    tap(app.buttons["下一章"])
    tap(app.buttons["暂无特别要求"])
    tap(app.buttons["下一章"])
    tap(app.buttons["成人人数"])
    app.buttons["1 人"].firstMatch.tap()
    tap(app.buttons["儿童人数"])
    app.buttons["0 人"].firstMatch.tap()
    tap(app.buttons["查看旅行心愿书"])
    tap(app.buttons["封面主题"])
    app.buttons["送给父母的心愿"].tap()
    let preview = XCTAttachment(screenshot: app.screenshot())
    preview.name = "心愿书人物封面"
    preview.lifetime = .keepAlways
    add(preview)
    XCTAssertFalse(app.staticTexts["参考内容"].exists)
    tap(app.buttons["提交行程愿望单"])
    XCTAssertTrue(app.navigationBars["联系与提交确认"].waitForExistence(timeout: 8))
    XCTAssertFalse(app.textFields["11 位手机号"].exists)
    XCTAssertFalse(app.buttons["login.sendCode"].exists)
    XCTAssertFalse(app.buttons["确认提交行程愿望单"].isEnabled)
    #if targetEnvironment(simulator)
    tap(app.switches["同意提交本次愿望单与联系方式"])
    tap(app.buttons["确认提交行程愿望单"])
    XCTAssertTrue(app.staticTexts["行程愿望单已接收"].waitForExistence(timeout: 6))
    #endif

  }

  func testPrepareConsultationReportsMissingFieldsAndOpensChapter() {
    app.launchSignedInForUITest()
    app.tabBars.buttons["设计旅行"].tap()
    app.buttons["新建一段旅行"].tap()
    tap(app.buttons["保存并返回"])
    tap(app.buttons["查看心愿书"].firstMatch)
    tap(app.buttons["提交行程愿望单"])
    XCTAssertTrue(app.navigationBars["咨询前还需补充"].waitForExistence(timeout: 5))
    app.buttons["填写成人和儿童人数（没有儿童请选择 0 人）"].tap()
    XCTAssertTrue(app.buttons["成人人数"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["儿童人数"].exists)
  }
}
