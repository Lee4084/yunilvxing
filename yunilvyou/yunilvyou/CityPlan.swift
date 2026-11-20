import SwiftUI

struct CityPlan: Decodable, Identifiable, Hashable {
  let id, city, title, summary, cover, price, date: String
  let number, days: Int
  var round: Int { number - 3 }
}

struct CityPlanDetail: Decodable {
  struct Fact: Decodable { let label, value: String }
  struct Day: Decodable, Identifiable {
    let number: Int
    let lines: [String]
    var id: Int { number }
  }
  let info: [Fact]
  let days: [Day]
  let photos: [String]
  let included, excluded: String
}

enum CityPlans {
  static let directory = Bundle.main.url(forResource: "CityRoutes", withExtension: "bundle")
  static let all: [CityPlan] = load("catalog") ?? []
  static let cities = all.filter { $0.number == 4 }.map(\.city)

  static func load<T: Decodable>(_ name: String) -> T? {
    guard let url = directory?.appendingPathComponent(name + ".json"),
          let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  static func photo(_ name: String) -> UIImage? {
    guard let path = directory?.appendingPathComponent(name + ".jpg").path else { return nil }
    return UIImage(contentsOfFile: path)
  }

  static func matches(_ query: String, city: String) -> [CityPlan] {
    let words = query.split(whereSeparator: \.isWhitespace)
    return all.filter { plan in
      guard city == "全部" || city == plan.city else { return false }
      let text = "\(plan.city) \(plan.title) \(plan.summary) \(plan.days)天 \(plan.number)号"
      return words.allSatisfy { text.localizedCaseInsensitiveContains(String($0)) }
    }
  }
}

private struct AlbumPicture: Identifiable {
  let id: String
  let number: Int
}

struct CityPlanPage: View {
  private enum SectionID: Hashable {
    case day(Int), included, excluded
  }

  let plan: CityPlan
  @State private var detail: CityPlanDetail?
  @State private var enlarged: AlbumPicture?
  @State private var consulting = false
  @State private var conversation = PlanConsultationStage.ready
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollViewReader { reader in
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("\(plan.city) · \(plan.number)号方案 · \(plan.days)天").font(.travel(.subheadline)).foregroundStyle(Ink.accent)
          Text(plan.title).font(.travel(.largeTitle)).accessibilityAddTraits(.isHeader)
          Text(plan.summary).font(.travel(.body))
          Text("原资料参考价 \(plan.price)\n记录于 \(plan.date) · 实际费用待沟通")
            .font(.travel(.footnote)).foregroundStyle(Ink.muted)
          if let detail {
            if !detail.info.isEmpty {
              Panel("方案信息") {
                ForEach(detail.info, id: \.label) { fact in
                  VStack(alignment: .leading, spacing: 4) {
                    Text(fact.label).font(.travel(.footnote)).foregroundStyle(Ink.accent)
                    Text(fact.value)
                  }
                }
              }
            }
            if let first = detail.photos.first {
              album([AlbumPicture(id: first, number: 1)], total: detail.photos.count)
            }
            ForEach(detail.days) { day in
              dayBody(day, detail: detail).id(SectionID.day(day.id))
            }
            if !detail.included.isEmpty { Panel("原方案费用包含") { Text(detail.included) }.id(SectionID.included) }
            if !detail.excluded.isEmpty { Panel("原方案费用不含") { Text(detail.excluded) }.id(SectionID.excluded) }
          } else {
            Text("暂时无法读取这份行程。").foregroundStyle(Ink.muted)
          }
        }
        .padding(16).padding(.bottom, 64).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
      }
      .background(Ink.canvas).foregroundStyle(Ink.text)
      .toolbar {
        if let detail {
          Menu {
            ForEach(detail.days) { day in
              Button("第\(day.number)天") { jump(to: .day(day.number), reader: reader) }
            }
            if !detail.included.isEmpty { Button("费用包含") { jump(to: .included, reader: reader) } }
            if !detail.excluded.isEmpty { Button("费用不含") { jump(to: .excluded, reader: reader) } }
          } label: { Label("行程目录", systemImage: "list.bullet") }
        }
      }
    }
    .onAppear { if detail == nil { detail = CityPlans.load(plan.id) } }
    .navigationTitle("行程方案")
    .overlay { FloatingConsultationButton { consulting = true } }
    .sheet(isPresented: $consulting) {
      CityPlanConsultation(plan: plan, stage: $conversation).travelSheetSizes()
    }
    .sheet(item: $enlarged) { photo in
      TravelSheetNavigation {
        if let image = CityPlans.photo(photo.id) {
          ScrollView {
            Image(uiImage: image).resizable().scaledToFit()
              .accessibilityLabel("\(plan.city)线路相册第\(photo.number)张")
          }.background(Ink.canvas)
            .navigationTitle("线路相册 · \(photo.number) / \(detail?.photos.count ?? 0)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("完成") { enlarged = nil } }
        }
      }
    }
  }

  private func jump(to section: SectionID, reader: ScrollViewProxy) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { reader.scrollTo(section, anchor: .top) }
  }

  // The archive supplies an ordered route album, without day-level photo captions.
  private func dayBody(_ day: CityPlanDetail.Day, detail: CityPlanDetail) -> some View {
    let remaining = max(0, detail.photos.count - 1)
    let start = min(1, detail.photos.count) + remaining * (day.number - 1) / detail.days.count
    let end = min(1, detail.photos.count) + remaining * day.number / detail.days.count
    let photos = (start..<end).map { AlbumPicture(id: detail.photos[$0], number: $0 + 1) }
    let paragraphs = readingBlocks(day.lines)
    return VStack(alignment: .leading, spacing: 14) {
      Text("第\(day.number)天").font(.travel(.title2)).foregroundStyle(Ink.accent)
        .accessibilityAddTraits(.isHeader)
      ForEach(paragraphs.indices, id: \.self) { index in
        Text(paragraphs[index]).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
        let lower = photos.count * index / paragraphs.count
        let upper = photos.count * (index + 1) / paragraphs.count
        if upper > lower { album(Array(photos[lower..<upper]), total: detail.photos.count) }
      }
      if paragraphs.isEmpty && !photos.isEmpty { album(photos, total: detail.photos.count) }
    }
    .padding(.vertical, 8)
  }

  private func readingBlocks(_ lines: [String]) -> [String] {
    var blocks: [String] = []
    var current = ""
    for line in lines {
      if !current.isEmpty && current.count + line.count > 240 {
        blocks.append(current)
        current = ""
      }
      current += (current.isEmpty ? "" : "\n") + line
    }
    if !current.isEmpty { blocks.append(current) }
    return blocks
  }

  private func album(_ pictures: [AlbumPicture], total: Int) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(pictures) { photo in
        if let image = CityPlans.photo(photo.id) {
          Button { enlarged = photo } label: {
            Image(uiImage: image).resizable().scaledToFit()
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }
          .buttonStyle(.plain)
          .accessibilityLabel("查看\(plan.city)线路相册第\(photo.number)张")
          Text("线路相册 · \(photo.number) / \(total)").font(.travel(.caption)).foregroundStyle(Ink.muted)
        }
      }
    }
  }
}

private struct FloatingConsultationButton: View {
  let open: () -> Void
  @State private var position = UnitPoint.bottomTrailing
  @State private var buttonSize = CGSize.zero
  @GestureState private var translation = CGSize.zero

  var body: some View {
    GeometryReader { page in
      let range = CGSize(width: max(0, page.size.width - buttonSize.width),
                         height: max(0, page.size.height - buttonSize.height))
      Label("客服", systemImage: "bubble.left.and.bubble.right.fill")
        .font(.travel(.headline)).padding(.horizontal, 16).frame(minHeight: 48)
        .foregroundStyle(.white).background(Color(red: 0.54, green: 0.20, blue: 0.17), in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .background {
          GeometryReader { label in
            Color.clear.onAppear { buttonSize = label.size }
              .onChange(of: label.size) { buttonSize = $0 }
          }
        }
        .contentShape(Capsule())
        .gesture(gesture(in: range))
        .accessibilityRepresentation {
          Button("客服", action: open).accessibilityHint("咨询当前旅行方案")
        }
        .offset(offset(in: range, translation: translation))
    }
    .padding(.horizontal, 8).padding(.vertical, 8)
  }

  private func offset(in range: CGSize, translation: CGSize) -> CGSize {
    CGSize(width: min(range.width, max(0, position.x * range.width + translation.width)),
           height: min(range.height, max(0, position.y * range.height + translation.height)))
  }

  private func gesture(in range: CGSize) -> some Gesture {
    let drag = DragGesture(minimumDistance: 6, coordinateSpace: .global)
      .updating($translation) { value, translation, _ in translation = value.translation }
      .onEnded { value in
        let end = offset(in: range, translation: value.translation)
        position = UnitPoint(x: range.width > 0 ? end.width / range.width : position.x,
                             y: range.height > 0 ? end.height / range.height : position.y)
      }
    return drag.exclusively(before: TapGesture().onEnded(open))
  }
}
