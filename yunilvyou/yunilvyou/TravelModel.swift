import Combine
import SwiftUI

struct Journey: Codable, Identifiable, Hashable {
  let id, title, category, summary, limits: String
  let theme: Int
  let steps, experiences: [String]
  let needs, included, excluded: String?
  let days: Int?
  var kind: String { days == nil ? "灵感示例" : "设计演示" }
  var duration: String { days.map { "\($0) 天" } ?? "行程待沟通" }
  let image: String
}

enum Catalog {
  static let themes = ["自己的特别一天", "两人的纪念日", "送给父母的心愿", "朋友的共同回忆"]
  static let categories = ["海岸", "城市", "山间", "海岛"]
  static let discoveryCovers = ["photo-361", "photo-011", "photo-029", "photo-227"]
  static let themeCovers = ["theme-solo", "theme-couple", "theme-family", "theme-friends"]
  static let chapters = ["为谁出发", "特别的理由", "想留下的回忆", "怎样才舒服", "出行条件"]
  static let items: [Journey] = {
    guard let url = Bundle.main.url(forResource: "Journeys", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let rows = try? JSONDecoder().decode([Journey].self, from: data)
    else { return [] }
    return rows
  }()
  static func matches(_ items: [Journey], query: String, category: String) -> [Journey] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return items.filter { item in
      let fields =
        [item.title, item.summary, item.duration, item.category, themes[item.theme]]
        + item.experiences + item.steps
      return (category == "全部" || item.category == category)
        && (term.isEmpty || fields.joined(separator: " ").localizedCaseInsensitiveContains(term))
    }
  }
}

struct Wish: Identifiable, Codable, Equatable {
  var id: String
  var title: String
}

struct Draft: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = "", lastStep = 0, theme: Int?
  var relations: [String] = [], customRelation = "", nickname = "", reason = "", customReason = "",
    message = ""
  var wishes: [Wish] = [], priority: [String] = [], equal = false, references: [String] = []
  var preferences: [String: String] = [:], avoids: [String] = [], note = "", noPreferences = false
  var start: Date?, end: Date?, days: Int?, adults: Int?, children: Int?, budget: Decimal?,
    scope: String?
  var destination = ""
  var name: String {
    if !title.trimmed.isEmpty { return title }
    let who =
      nickname.trimmed.isEmpty
      ? relations.map { $0 == "自定义" ? customRelation : $0 }.joined(separator: "、") : nickname
    if who.isEmpty { return "未命名旅行" }
    return "给" + (who == "为自己" ? "自己" : who) + "的一次特别旅行"
  }
  var partyValid: Bool {
    guard let adults, let children else { return false }
    return adults >= 1 && children >= 0 && adults + children <= 99
  }
  var completed: [Bool] {
    [
      !relations.isEmpty && (!relations.contains("自定义") || customRelation.valid(100))
        && nickname.optionalValid(20),
      !reason.isEmpty && (reason != "自定义" || customReason.valid(100)) && message.optionalValid(300),
      !wishes.isEmpty && (equal || !priority.isEmpty),
      (noPreferences || !preferences.isEmpty || !avoids.isEmpty || !note.isEmpty)
        && note.optionalValid(300),
      partyValid && destination.optionalValid(100)
        && (start.map { $0 >= TravelDates.calendar.startOfDay(for: .now) } ?? true),
    ]
  }
  var ready: Bool {
    [0, 1, 2, 4].allSatisfy { completed[$0] } && title.optionalValid(40) && note.optionalValid(300)
  }
  mutating func merge(_ journey: Journey, selected: Set<Int>) -> Bool {
    let additions = journey.experiences.enumerated().compactMap { index, title -> Wish? in
      let key = "\(journey.id)-E\(index + 1)"
      guard selected.contains(index), !wishes.contains(where: { $0.id == key }) else { return nil }
      return Wish(id: key, title: title)
    }
    guard wishes.count + additions.count <= 20 else { return false }
    wishes += additions
    if !references.contains(journey.id) { references.append(journey.id) }
    return true
  }
}
extension String {
  var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
  func valid(_ limit: Int) -> Bool { !trimmed.isEmpty && count <= limit }
  func optionalValid(_ limit: Int) -> Bool { isEmpty || valid(limit) }
}

struct ContactPreferences: Codable {
  var channel = "", time = "", customTime = ""
  var surprise = false
}

struct LibraryData: Codable {
  var contactPreferences: ContactPreferences?
  var drafts: [Draft] = []
  var favorites: Set<String> = []
}

final class Library: ObservableObject {
  @Published private(set) var data = LibraryData()
  @Published var error: String?
  @Published private(set) var demoHistory: [DemoConsultation] = []

  func simulate(draft: Draft, outcome: DemoOutcome) -> UUID {
    let record = DemoConsultation(draft: draft)
    demoHistory.insert(record, at: 0)
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 1_200_000_000)
      finishDemo(record.id, as: outcome)
    }
    return record.id
  }

  func finishDemo(_ id: UUID, as outcome: DemoOutcome) {
    guard let index = demoHistory.firstIndex(where: { $0.id == id }) else { return }
    demoHistory[index].outcome = outcome
  }
  func clearLocalData() {
    if persist(LibraryData()) { demoHistory = [] }
  }

  private var saved = LibraryData()
  private var pending: LibraryData?
  private var loadFailed = false
  private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("wishbooks.json")
  init() { load() }
  func load() {
    do {
      if FileManager.default.fileExists(atPath: url.path) {
        data = try JSONDecoder().decode(LibraryData.self, from: Data(contentsOf: url))
      }
      saved = data
      loadFailed = false
    } catch {
      loadFailed = true
      self.error = "未能读取本机资料，请重试。"
    }
  }
  @discardableResult func persist(_ next: LibraryData, keepEditing: Bool = false) -> Bool {
    guard !loadFailed else {
      error = "未能读取本机资料，请重试。"
      return false
    }
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(next).write(to: url, options: .atomic)
      data = next
      saved = next
      pending = nil
      return true
    } catch {
      pending = next
      if keepEditing { data = next }
      self.error = "未能保存，请重试后再离开。"
      return false
    }
  }
  func retry() { if loadFailed { load() } else if let pending { persist(pending) } }
  func discard() {
    pending = nil
    data = saved
  }
  @discardableResult func save(_ draft: Draft) -> Bool {
    var next = data
    next.drafts.removeAll { $0.id == draft.id }
    next.drafts.insert(draft, at: 0)
    return persist(next, keepEditing: data.drafts.contains { $0.id == draft.id })
  }
  var contactBinding: Binding<ContactPreferences> {
    Binding(
      get: { self.data.contactPreferences ?? ContactPreferences() },
      set: { value in
        var next = self.data
        next.contactPreferences = value
        self.persist(next, keepEditing: true)
      })
  }
  func favorite(_ id: String) {
    var next = data
    if next.favorites.remove(id) == nil { next.favorites.insert(id) }
    persist(next)
  }
}

enum TravelDates {
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return calendar
  }()
  static func display(_ date: Date) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(parts.year!)年\(parts.month!)月\(parts.day!)日"
  }
}
