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
    app.launch()
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

  func testDemoNumberSubmissionAndHistory() {
    app.launch()
    app.tabBars.buttons["我的"].tap()
    tap(app.buttons["体验一次模拟咨询"])
    submitDemo()
    XCTAssertTrue(app.tabBars.buttons["灵感故事"].isSelected)
    XCTAssertFalse(app.navigationBars["模拟咨询"].exists)
    app.tabBars.buttons["我的"].tap()
    XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout: 6))
    app.tabBars.buttons["灵感故事"].tap()
    tap(app.buttons["查看本次提交结果"])
    XCTAssertTrue(app.navigationBars["模拟提交结果"].waitForExistence(timeout: 6))
    tap(app.buttons["查看本机演示记录"])
    XCTAssertTrue(app.staticTexts["本机演示记录"].waitForExistence(timeout: 6))
  }

  private func submitDemo() {
    XCTAssertTrue(app.staticTexts["DEMO-0001"].waitForExistence(timeout: 6))
    tap(app.buttons["模拟验证号码"])
    XCTAssertTrue(app.staticTexts["虚拟号码已模拟验证"].waitForExistence(timeout: 6))
    tap(app.switches["我确认体验本机模拟提交"])
    XCTAssertTrue(app.buttons["模拟提交我的旅行需求"].isEnabled)
    tap(app.buttons["模拟提交我的旅行需求"])
    XCTAssertTrue(app.staticTexts["模拟需求已接收"].waitForExistence(timeout: 8))
  }

  func testIOS15WishbookSubmissionReturnsHome() {
    app.launchArguments.append("-testIOS15Interaction")
    verifyCompletedWishbookSubmission()
  }

  func testCompletedWishbookSubmissionReturnsHome() {
    verifyCompletedWishbookSubmission()
  }

  private func verifyCompletedWishbookSubmission() {
    app.launch()
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
    tap(app.buttons["提交心愿书（本机演示）"])
    XCTAssertTrue(app.staticTexts["模拟需求已接收"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.tabBars.buttons["灵感故事"].isSelected)
    XCTAssertTrue(app.buttons["查看本次提交结果"].exists)
    app.tabBars.buttons["设计旅行"].tap()
    XCTAssertTrue(app.buttons["新建一段旅行"].waitForExistence(timeout: 6))
  }

  func testPrepareConsultationReportsMissingFieldsAndOpensChapter() {
    app.launch()
    app.tabBars.buttons["设计旅行"].tap()
    app.buttons["新建一段旅行"].tap()
    tap(app.buttons["保存并返回"])
    tap(app.buttons["查看心愿书"].firstMatch)
    tap(app.buttons["提交心愿书（本机演示）"])
    XCTAssertTrue(app.navigationBars["咨询前还需补充"].waitForExistence(timeout: 5))
    app.buttons["填写成人和儿童人数（没有儿童请选择 0 人）"].tap()
    XCTAssertTrue(app.buttons["成人人数"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["儿童人数"].exists)
  }
}
