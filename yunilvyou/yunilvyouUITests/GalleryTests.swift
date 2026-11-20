import XCTest

@MainActor final class GalleryTests: XCTestCase {
  func testMyTravelCoverPhotos() {
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["我的"].tap()
    let album = app.descendants(matching: .any)["hero.mine"].firstMatch
    XCTAssertTrue(album.waitForExistence(timeout: 8))
    let title = app.staticTexts["我的旅行"]
    let titleFrame = title.frame
    for (page, scene) in ["新疆", "雪山", "桂林", "城市"].enumerated() {
      if page > 0 { album.swipeLeft() }
      let displayed = NSPredicate(format: "value == %@", "第\(page + 1)张，共4张")
      let expectation = XCTNSPredicateExpectation(predicate: displayed, object: album)
      XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
      XCTAssertEqual(title.frame, titleFrame)
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = scene
      capture.lifetime = .keepAlways
      add(capture)
    }
  }

  func testCoverAlbumsAndMoreCities() {
    let app = XCUIApplication()
    app.launch()
    for (tab, album, caption) in [("灵感故事", "home", "为自己，也为心里重要的人。"),
                                  ("我的", "mine", "草稿与收藏，仅保存在这台设备上。"),
                                  ("设计旅行", "design", "五个轻松的步骤，整理你真正期待的体验。"),
                                  ("精选行程", "trips", "慢慢滑动，点选想停留的那一程。")] {
      app.tabBars.buttons[tab].tap()
      let hero = app.descendants(matching: .any)["hero." + album].firstMatch
      XCTAssertTrue(hero.waitForExistence(timeout: 10))
      let text = app.staticTexts[caption]
      let original = text.frame
      let initial = hero.value as? String
      hero.swipeLeft()
      let changed = NSPredicate { _, _ in (hero.value as? String) != initial }
      XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: nil)], timeout: 6), .completed)
      XCTAssertEqual(text.frame, original)
    }
    app.buttons["灵感示例"].tap()
    app.tabBars.buttons["灵感故事"].tap()
    let shelf = app.scrollViews["home.shelf.精选行程"]
    for _ in 0..<12 where !shelf.exists || shelf.frame.midY > app.frame.height * 0.78 { app.swipeUp() }
    let more = shelf.buttons["home.moreCities"]
    for _ in 0..<10 where !more.isHittable { shelf.swipeLeft() }
    XCTAssertTrue(more.isHittable)
    more.tap()
    XCTAssertTrue(app.staticTexts["城市旅行方案"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.tabBars.buttons["精选行程"].isSelected)
  }

  func testCityPlanConsultation() {
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["精选行程"].tap()
    app.buttons["city-01-4"].tap()
    let entry = app.buttons["查看图文行程"]
    reveal(entry, in: app)
    entry.tap()
    let support = app.buttons["客服"]
    XCTAssertTrue(support.waitForExistence(timeout: 8))
    let center = CGVector(dx: 0.5, dy: 0.5)
    let leftEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
    support.coordinate(withNormalizedOffset: center).press(forDuration: 0.1, thenDragTo: leftEdge)
    XCTAssertGreaterThanOrEqual(support.frame.minX, app.frame.minX)
    XCTAssertLessThan(support.frame.minX, app.frame.minX + 20)
    let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.36))
    support.coordinate(withNormalizedOffset: center).press(forDuration: 0.1, thenDragTo: destination)
    XCTAssertEqual(support.frame.midX, destination.screenPoint.x, accuracy: 8)
    XCTAssertEqual(support.frame.midY, destination.screenPoint.y, accuracy: 8)
    XCTAssertFalse(app.buttons["关闭咨询"].exists)
    let placed = support.frame
    app.swipeUp()
    XCTAssertEqual(support.frame, placed)
    let moved = XCTAttachment(screenshot: app.screenshot())
    moved.name = "客服按钮自由摆放"
    moved.lifetime = .keepAlways
    add(moved)
    support.tap()
    XCTAssertTrue(app.staticTexts["上海迪士尼与黄浦江游船"].firstMatch.waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["上海 · 4号方案"].exists)
    app.buttons["发送"].tap()
    XCTAssertTrue(app.staticTexts["收到您想了解的行程啦。方便留个联系电话吗？我们会尽快联系您，一起聊聊这趟旅行。"].exists)
    app.buttons["发送"].tap()
    XCTAssertTrue(app.staticTexts["请输入有效的联系电话。"].exists)
    let number = app.textFields["联系电话"]
    number.tap()
    number.typeText("00000000000")
    app.buttons["发送"].tap()
    XCTAssertTrue(app.staticTexts["谢谢您留下号码，稍后请留意来电。期待听听您对这趟旅行的想法。"].waitForExistence(timeout: 6))
    XCTAssertTrue(app.staticTexts["联系电话 · 尾号 0000"].exists)
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "方案咨询会话"
    capture.lifetime = .keepAlways
    add(capture)
    app.buttons["关闭咨询"].tap()
    XCTAssertEqual(support.frame, placed)
    support.tap()
    XCTAssertTrue(app.staticTexts["谢谢您留下号码，稍后请留意来电。期待听听您对这趟旅行的想法。"].exists)
  }
  func testHomeShelvesSwipeAndOpenDetails() {
    let app = XCUIApplication()
    app.launch()
    for (title, destination) in [("从一个故事开始", "故事详情"), ("精选行程", "行程详情")] {
      let shelf = app.scrollViews["home.shelf." + title]
      for _ in 0..<10 where !shelf.exists || shelf.frame.midY > app.frame.height * 0.78 {
        app.swipeUp()
      }
      XCTAssertTrue(shelf.isHittable)
      let first = shelf.buttons.firstMatch
      let firstID = first.identifier
      let initialX = first.frame.midX
      let start = shelf.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.45))
      let end = shelf.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.45))
      start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.35)
      let next = shelf.buttons.allElementsBoundByIndex.first {
        $0.isHittable && abs($0.frame.midX - initialX) < 100
      }
      XCTAssertNotNil(next)
      XCTAssertNotEqual(next?.identifier, firstID)
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = title
      screenshot.lifetime = .keepAlways
      add(screenshot)
      next?.tap()
      XCTAssertTrue(app.navigationBars[destination].waitForExistence(timeout: 8))
      app.navigationBars.buttons.firstMatch.tap()
    }
  }
  func testStoryAndStructureRoutes() throws {
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["精选行程"].tap()
    app.buttons["灵感示例"].tap()
    let category = app.buttons["海岸"]
    XCTAssertTrue(category.waitForExistence(timeout: 8))
    category.tap()
    XCTAssertEqual(app.staticTexts["gallery.count"].label, "共 3 个结果")
    let card = app.buttons["YN-S01"]
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    card.tap()
    let story = app.buttons["查看这段灵感"]
    reveal(story, in: app)
    story.tap()
    XCTAssertTrue(app.navigationBars["故事详情"].waitForExistence(timeout: 4))
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(story.waitForExistence(timeout: 4))
    app.swipeDown()
    app.buttons["山间"].tap()
    let product = app.buttons["YN-PROD02"]
    product.tap()
    let structure = app.buttons["查看行程结构"]
    reveal(structure, in: app)
    structure.tap()
    XCTAssertTrue(app.navigationBars["行程详情"].waitForExistence(timeout: 4))
    XCTAssertTrue(app.staticTexts["山间相伴 · 两日参考"].exists)
  }
  func testFilteringAndFreeScroll() throws {
    let app = XCUIApplication()
    app.launch()
    app.tabBars.buttons["精选行程"].tap()
    app.buttons["灵感示例"].tap()
    let track = app.scrollViews["gallery.track"]
    XCTAssertTrue(track.waitForExistence(timeout: 6))
    let start = track.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.42))
    let end = track.coordinate(withNormalizedOffset: CGVector(dx: 0.49, dy: 0.42))
    start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    let first = app.buttons["YN-S01"]
    let center = track.frame.midX
    XCTAssertGreaterThan(center - first.frame.midX, 15, "松手后应停留在两张卡片之间")
    XCTAssertFalse(app.buttons["查看这段灵感"].exists)
    XCTAssertFalse(app.buttons["查看行程结构"].exists)
    first.tap()
    let centered = NSPredicate { _, _ in abs(first.frame.midX - center) < 4 }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: centered, object: nil)], timeout: 4), .completed)
    XCTAssertTrue(app.buttons["查看这段灵感"].exists)
    let input = app.textFields["搜索精选旅程"]
    input.tap()
    input.typeText("3\n")
    XCTAssertEqual(app.staticTexts["gallery.count"].label, "共 1 个结果")
    app.buttons["海岛"].tap()
    XCTAssertTrue(app.staticTexts["没有找到匹配的旅程"].exists)
    app.buttons["重置搜索与筛选"].tap()
    XCTAssertEqual(app.staticTexts["gallery.count"].label, "共 10 个结果")
  }
  func testIOS15CityPlanSelectionAndDetail() {
    let app = XCUIApplication()
    app.launchArguments.append("-testIOS15Interaction")
    verifyCityPlan(in: app)
  }
  func testCityPlanSelectionAndDetail() {
    verifyCityPlan(in: XCUIApplication())
  }
  private func verifyCityPlan(in app: XCUIApplication) {
    app.launch()
    app.tabBars.buttons["精选行程"].tap()
    let firstCard = app.buttons["city-01-4"]
    XCTAssertTrue(firstCard.waitForExistence(timeout: 20))
    XCTAssertFalse(firstCard.label.contains("轮"))
    XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "轮")).firstMatch.exists)
    XCTAssertFalse(app.descendants(matching: .any)["浏览位置"].exists)
    let preview = XCTAttachment(screenshot: app.screenshot())
    preview.name = "城市旅行方案"
    preview.lifetime = .keepAlways
    add(preview)
    XCTAssertFalse(app.staticTexts["gallery.count"].exists)
    app.buttons["广州"].tap()
    XCTAssertFalse(app.staticTexts["gallery.count"].exists)
    let track = app.scrollViews["gallery.track"]
    let step = track.frame.width * 0.82 + 12
    let start = track.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.25))
    let end = start.withOffset(CGVector(dx: -step, dy: 0))
    for id in ["city-03-5", "city-03-4", "city-03-5", "city-03-4"] {
      start.press(forDuration: 0.12, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.35)
      let card = app.buttons[id]
      XCTAssertLessThan(abs(card.frame.midX - track.frame.midX), step / 2, "循环浏览时应出现对应方案")
      XCTAssertFalse(app.buttons["查看图文行程"].exists)
    }
    app.buttons["city-03-4"].tap()
    let entry = app.buttons["查看图文行程"]
    reveal(entry, in: app)
    entry.tap()
    XCTAssertTrue(app.navigationBars["行程方案"].waitForExistence(timeout: 8))
    app.buttons["行程目录"].tap()
    app.buttons["第7天"].tap()
    XCTAssertTrue(app.staticTexts["第7天"].waitForExistence(timeout: 8))
  }
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<4 where !element.isHittable { app.swipeUp() }
    XCTAssertTrue(element.isHittable)
  }
}
