import SwiftUI

enum Root: String, CaseIterable {
  case home = "灵感故事"
  case design = "设计旅行"
  case trips = "精选行程"
  case mine = "我的"
  var icon: String {
    switch self {
    case .home: "sun.horizon"
    case .design: UIImage(systemName: "book.pages") == nil ? "book" : "book.pages"
    case .trips: "rectangle.stack"
    case .mine: "person.crop.circle"
    }
  }
}
enum Route: Hashable {
  case discover(Int)
  case detail(Journey)
  case cityPlan(CityPlan)
  case chapter(UUID, Int, editing: Bool)
  case demoConsult(UUID?)
  case demoResult(UUID)
  case book(UUID)
  case contact(UUID)
  case library, records, help, receipt
}
struct ContentView: View {
  @State private var root: Root = .home
  @StateObject private var library = Library()
  @State private var paths: [Root: [Route]] = [:]
  @State private var cityRequest = 0
  @State private var homeSubmission: UUID?
  var body: some View {
    Group {
      if #available(iOS 16, *), !TravelCompatibility.useLegacyNavigation {
        tabs
      } else {
        NavigationView {
          tabs
            .background(stack(for: root, routesOnly: true).id(root))
            .navigationTitle(root == .home ? "予你旅行" : root.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(root == .home)
        }.navigationViewStyle(.stack)
      }
    }.environmentObject(library).tint(Ink.accent).environment(\.locale, Locale(identifier: "zh_CN"))
      .alert(
        "本机资料",
        isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })
      ) {
        Button("重试") { library.retry() }
        Button("继续编辑", role: .cancel) {}
        Button("放弃未保存的修改", role: .destructive) { library.discard() }
      } message: {
        Text(library.error ?? "")
      }
  }
  private var tabs: some View {
    TabView(selection: $root) {
      ForEach(Root.allCases, id: \.self) { tab in
        stack(for: tab).tabItem { Label(tab.rawValue, systemImage: tab.icon) }.tag(tab)
      }
    }
  }
  private func stack(for tab: Root, routesOnly: Bool = false) -> RootStack {
    RootStack(tab: tab, selectedTab: $root,
      path: Binding(get: { paths[tab] ?? [] }, set: { paths[tab] = $0 }),
      homeSubmission: $homeSubmission, submitted: { id in
        paths[tab] = []
        paths[.home] = []
        homeSubmission = id
        root = .home
      }, routesOnly: routesOnly, cityRequest: cityRequest, showCityPlans: {
        paths[.trips] = []
        cityRequest += 1
        root = .trips
      })
  }
}
struct RootStack: View {
  let tab: Root
  @Binding var selectedTab: Root
  @EnvironmentObject var library: Library
  @Binding var path: [Route]
  @Binding var homeSubmission: UUID?
  let submitted: (UUID) -> Void
  let routesOnly: Bool
  let cityRequest: Int
  let showCityPlans: () -> Void
  func open(_ route: Route) { path.append(route) }
  var body: some View {
    if routesOnly {
      legacyLink(after: [])
    } else if #available(iOS 16, *), !TravelCompatibility.useLegacyNavigation {
      NavigationStack(path: $path) {
        rootPage.navigationTitle(tab == .home ? "予你旅行" : tab.rawValue)
          .navigationBarTitleDisplayMode(.inline)
          .toolbar(tab == .home ? .hidden : .visible, for: .navigationBar)
          .navigationDestination(for: Route.self) { route in
            destination(route).toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
              .navigationBarTitleDisplayMode(.inline)
          }
      }
    } else {
      rootPage
    }
  }
  @ViewBuilder private var rootPage: some View {
    switch tab {
    case .home: home
    case .trips: JourneyGallery(open: open).id(cityRequest)
    case .design: design
    case .mine: mine
    }
  }
  // A link at each depth reflects the same route array as the newer navigation stack.
  // Pushing above the tab view also gives child pages the full iPhone screen on iOS 15.
  private func legacyLink(after prefix: [Route]) -> some View {
    let next = path.starts(with: prefix) && path.count > prefix.count ? path[prefix.count] : nil
    return NavigationLink(isActive: Binding(get: { next != nil }, set: { active in
      if !active, let next, path.starts(with: prefix + [next]) { path = prefix }
    })) {
      if let next {
        destination(next).id(next)
          .navigationBarHidden(false).navigationBarTitleDisplayMode(.inline)
          .background(AnyView(legacyLink(after: prefix + [next])))
      }
    } label: { EmptyView() }
      .isDetailLink(false).accessibilityHidden(true).frame(width: 0, height: 0)
  }
  @ViewBuilder func destination(_ route: Route) -> some View {
    switch route {
    case .discover(let theme):
      Discovery(initial: theme, open: open) {
        selectedTab = .design
        path = []
      }
    case .detail(let item): JourneyDetail(item: item, open: open)
    case .cityPlan(let plan): CityPlanPage(plan: plan)
    case .chapter(let id, let step, let editing):
      if let draft = binding(id) {
        ChapterView(
          draft: draft, step: step, editing: editing,
          advance: { next in
            if editing {
              path.removeLast()
            } else if next == 5 {
              open(.book(id))
            } else {
              open(.chapter(id, next, editing: false))
            }
          },
          jump: { index in
            if editing {
              path[path.count - 1] = .chapter(id, index, editing: true)
            } else {
              open(.chapter(id, index, editing: false))
            }
          },
          exit: {
            path = []
            selectedTab = .design
          })
      }
    case .book(let id): if let draft = binding(id) { Wishbook(draft: draft, open: open, submitted: submitted) }
    case .contact(let id):
      if let draft = binding(id) { ContactPage(draft: draft.wrappedValue, open: open) }
    case .demoConsult(let id):
      DemoConsultationForm(
        draft: library.data.drafts.first { $0.id == id } ?? DemoConsultation.example, submitted: submitted)
    case .demoResult(let id): DemoResultPage(id: id, open: open)
    case .library: LocalShelf(open: open)
    case .records: RecordsPage(open: open)
    case .receipt: ReceiptExample()
    case .help: HelpPage()
    }
  }
  func binding(_ id: UUID) -> Binding<Draft>? {
    guard let original = library.data.drafts.first(where: { $0.id == id }) else { return nil }
    return Binding(
      get: { library.data.drafts.first(where: { $0.id == id }) ?? original },
      set: { library.save($0) })
  }
  var home: some View {
    TravelPage {
      if let record = library.demoHistory.first(where: { $0.id == homeSubmission }) {
        Panel(record.homeStatus) {
          Text(record.draft.name)
          Button(record.outcome == .unknown ? "查看并核验本次请求" : "查看本次提交结果") {
            open(.demoResult(record.id))
          }
          Button("收起提示") { homeSubmission = nil }
        }
      }
      WelcomeScene()
      VStack(spacing: 14) {
        Button("探索旅行灵感") { open(.discover(0)) }
          .buttonStyle(WelcomeButtonStyle(symbol: "arrow.up.right"))
        Button("直接设计我的旅行") { selectedTab = .design }
          .buttonStyle(WelcomeButtonStyle(symbol: "arrow.right"))
      }
      if let draft = library.data.drafts.first { draftRow(draft) }
      Text("选一处出发心境").font(.travel(.title2))
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          ForEach(Catalog.themes.indices, id: \.self) { i in
            Button {
              open(.discover(i))
            } label: {
              Cover(
                image: Catalog.discoveryCovers[i], eyebrow: Catalog.categories[i], title: "",
                subtitle: Catalog.themes[i], height: 120
              ).frame(width: 160).contentShape(Rectangle())
            }.buttonStyle(.plain)
          }
        }
      }
      HomeJourneyShelf(title: "从一个故事开始", cards: Catalog.items.filter { $0.days == nil }.map { GalleryCard($0) }, open: open)
      HomeJourneyShelf(title: "精选行程", cards: featuredJourneys, open: open, more: showCityPlans)
    }.id(homeSubmission)
  }
  private var featuredJourneys: [GalleryCard] {
    let examples = Catalog.items.filter { $0.days != nil }.map { GalleryCard($0) }
    let cities = CityPlans.all.filter { $0.number == 4 && ["成都", "桂林", "海南", "新疆"].contains($0.city) }
    return examples + cities.map { GalleryCard($0) }
  }
  var design: some View {
    TravelPage {
      Cover(
        image: "hills", eyebrow: "YOUR STORY, YOUR JOURNEY", title: "把心愿，\n写进旅程。",
        subtitle: "五个轻松的步骤，整理你真正期待的体验。", album: .design)
      MainButton("新建一段旅行") {
        let draft = Draft()
        if library.save(draft) { open(.chapter(draft.id, 0, editing: false)) }
      }
      Text("每份草稿独立保存在本机。").font(.travel(.footnote)).foregroundStyle(Ink.muted)
      ForEach(library.data.drafts) { draft in draftRow(draft) }
      Button("管理草稿与收藏") { open(.library) }
      Button("查看本机提交记录") { open(.records) }
    }
  }
  func draftRow(_ draft: Draft) -> some View {
    Panel(draft.name) {
      Text("已完成 \(draft.completed.filter { $0 }.count) / 5 章 · 本机草稿").font(.travel(.footnote))
      Button("继续设计") { open(.chapter(draft.id, draft.lastStep, editing: false)) }
      Button("查看心愿书") { open(.book(draft.id)) }
    }
  }
  var mine: some View {
    TravelPage {
      Cover(
        image: "island", eyebrow: "YOUR TRAVEL DESK", title: "我的旅行", subtitle: "草稿与收藏，仅保存在这台设备上。",
        height: 190, album: .mine)
      Panel("我的心愿书") {
        if let latest = library.data.drafts.first {
          Text(latest.name).font(.travel(.title2))
          Text("\(latest.wishes.count) 项愿望 · 已完成 \(latest.completed.filter { $0 }.count) / 5 章")
            .font(.travel(.footnote))
          ForEach(latest.wishes.prefix(3)) { wish in
            Label(
              wish.title, systemImage: latest.priority.contains(wish.id) ? "star.fill" : "heart")
          }
          MainButton("打开这份心愿书") { open(.book(latest.id)) }
          if library.data.drafts.count > 1 { Button("查看全部心愿书") { open(.library) } }
        } else {
          Text("想和谁出发，想留下什么回忆？把第一份心愿写下来。")
          MainButton("写我的第一份心愿书") {
            let draft = Draft()
            if library.save(draft) { open(.chapter(draft.id, 0, editing: false)) }
          }
        }
      }
      ContactPreferencePanel(preferences: library.contactBinding)
      MainButton("体验一次模拟咨询") { open(.demoConsult(nil)) }
      Panel("本机内容") {
        Button("我的草稿　\(library.data.drafts.count) 份") { open(.library) }
        Divider()
        Button("我的收藏　\(library.data.favorites.count) 项") { open(.library) }
        Divider()
        Button("提交记录　0 条") { open(.records) }
      }
      Button("帮助与隐私") { open(.help) }
    }
  }
}

private struct HomeJourneyShelf: View {
  let title: String
  let cards: [GalleryCard]
  let open: (Route) -> Void
  var more: (() -> Void)?
  @ScaledMetric(relativeTo: .body) private var width: CGFloat = 264

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.travel(.title2)).accessibilityAddTraits(.isHeader)
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 12) {
          ForEach(cards) { card in
            Button { open(card.route) } label: {
              Cover(image: card.image, eyebrow: "\(card.isCity ? "行程参考" : card.kind) · 费用待沟通",
                    title: card.title, subtitle: card.summary, height: 180)
                .frame(width: min(285, width)).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(card.title).accessibilityHint("查看详情")
            .accessibilityIdentifier("home." + card.id)
          }
          if let more {
            Button(action: more) {
              VStack(spacing: 4) {
                Text("更")
                Text("多")
              }
              .font(.travel(.headline)).foregroundStyle(Ink.accent)
              .frame(minWidth: 54, minHeight: 180)
              .background(Ink.paper, in: RoundedRectangle(cornerRadius: 12))
              .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.line))
              .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("更多").accessibilityHint("打开精选行程的城市方案")
            .accessibilityIdentifier("home.moreCities")
          }
        }
      }.accessibilityIdentifier("home.shelf." + title)
    }
  }
}
