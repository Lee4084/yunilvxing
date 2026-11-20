import CoreText
import Foundation
import Testing

@testable import yunilvyou

@MainActor struct JourneyTests {
  @Test func catalogAndCombinedSearch() {
    let items = Catalog.items
    #expect(items.count == 10)
    #expect(Set(items.map(\.id)).count == 10)
    #expect(items.filter { $0.days == nil }.count == 8)
    #expect(items.compactMap(\.days).sorted() == [2, 3])
    #expect(
      Catalog.categories.map { Catalog.matches(items, query: "", category: $0).count } == [
        3, 2, 3, 2,
      ])
    #expect(Catalog.matches(items, query: " 三日 ", category: "海岸").map(\.id) == ["YN-PROD01"])
    #expect(Catalog.matches(items, query: "三日", category: "海岛").isEmpty)
    #expect(Catalog.matches(items, query: "交换旅行寄语", category: "全部").map(\.id) == ["YN-S07"])
  }

  @Test func consultationOnlyKeepsPhoneSuffix() {
    #expect(PlanConsultationStage.phoneSuffix("00000000000") == "0000")
    #expect(PlanConsultationStage.phoneSuffix("+86 138-0000-1234") == "1234")
    for invalid in ["", "123", "1234567x", "12+34567", "1234567890123456"] {
      #expect(PlanConsultationStage.phoneSuffix(invalid) == nil)
    }
  }

  @Test func daylightCoversAreDistinctAndAvailable() {
    let names = Catalog.discoveryCovers + Catalog.items.map(\.image)
    #expect(names.count == 14)
    #expect(Set(names).count == names.count)
    for name in names { #expect(CityPlans.photo(name) != nil) }
  }

  @Test func archivedPlansKeepCityRoundsAndLocalMedia() throws {
    let cities = CityPlans.cities
    #expect(cities.count == 15)
    #expect(Set(cities).count == 15)
    let rows = CityPlans.all
    #expect(rows.count == 44)
    #expect(Set(rows.map(\.id)).count == 44)
    #expect(Set(rows.map(\.cover)).count == rows.count)
    #expect(rows.map(\.number) == Array(repeating: 4, count: 15)
      + Array(repeating: 5, count: 15) + Array(repeating: 6, count: 14))
    #expect(rows.filter { $0.number == 5 }.map(\.city) == cities)
    #expect(rows.filter { $0.number == 6 }.map(\.city) == cities.filter { $0 != "广州" })
    let directory = try #require(CityPlans.directory)
    for plan in rows {
      let detail: CityPlanDetail = try #require(CityPlans.load(plan.id))
      #expect(detail.days.map(\.number) == Array(1...plan.days))
      #expect(detail.days.allSatisfy { !$0.lines.isEmpty })
      #expect(detail.photos.contains(plan.cover))
      for name in detail.photos + [plan.cover + "-cover"] {
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(name + ".jpg").path))
      }
    }
  }
  @Test func localTypefaceCoversTheTravelCopy() throws {
    let font = CTFontCreateWithName(TravelTypography.face as CFString, 18, nil)
    #expect(CTFontCopyPostScriptName(font) as String == TravelTypography.face)
    var copy = "城市旅行方案精选旅程心愿风景"
    let directory = try #require(CityPlans.directory)
    for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
      where file.pathExtension == "json" {
      copy += try String(contentsOf: file, encoding: .utf8)
    }
    let characters = Array(Set(copy.utf16.filter { (0x3400...0x9fff).contains($0) }))
    var glyphs = [CGGlyph](repeating: 0, count: characters.count)
    let covered = CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
    #expect(covered)
  }

  @Test func atomicImportAndPriority() throws {
    let story = try #require(Catalog.items.first)
    var draft = Draft()
    let added = draft.merge(story, selected: [0, 2])
    #expect(added)
    let deduplicated = draft.merge(story, selected: [2])
    #expect(deduplicated)
    #expect(draft.wishes.count == 2)
    #expect(draft.priority.isEmpty)
    #expect(draft.references == [story.id])
    draft.wishes += (0..<18).map { Wish(id: "custom-\($0)", title: "\($0)") }
    let original = draft
    let overflow = draft.merge(story, selected: [0, 1])
    #expect(!overflow)
    #expect(draft == original)
  }
}
