import SwiftUI

struct Discovery: View {
  @State private var theme: Int
  @State private var kind = "全部"
  let open: (Route) -> Void, design: () -> Void
  init(initial: Int, open: @escaping (Route) -> Void, design: @escaping () -> Void) {
    _theme = State(initialValue: initial)
    self.open = open
    self.design = design
  }
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    ScrollViewReader { reader in
      TravelPage {
        Cover(
          image: Catalog.discoveryCovers[theme], eyebrow: "FIND YOUR KIND OF JOURNEY",
          title: "去哪一种风景里，\n留下回忆？", subtitle: Catalog.themes[theme], height: 200)
        Panel("选一份出发心境") {
          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 1 : 2),
            spacing: 10
          ) {
            ForEach(Catalog.themes.indices, id: \.self) { i in
              Choice(title: Catalog.themes[i], selected: theme == i) {
                theme = i
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                  reader.scrollTo("discovery.stories", anchor: .top)
                }
              }.accessibilityHint("查看这个主题的故事").accessibilityIdentifier("theme.\(i)")
            }
          }
        }
        VStack(alignment: .leading, spacing: 12) {
          Text(Catalog.themes[theme]).font(.travel(.title2)).accessibilityAddTraits(.isHeader)
          TravelMenu(title: "故事类型", value: kind) {
            ForEach(["全部", "真实案例", "灵感示例"], id: \.self) { value in Button(value) { kind = value } }
          }
        }.id("discovery.stories")
        if kind == "真实案例" {
          EmptyMessage("目前没有已授权的真实案例", systemImage: "book")
          MainButton("浏览灵感示例") { kind = "灵感示例" }
        } else {
          ForEach(
            Catalog.items.filter { $0.days == nil && $0.theme == theme }.sorted { $0.id < $1.id }
          ) { item in
            Button {
              open(.detail(item))
            } label: {
              VStack(alignment: .leading, spacing: 0) {
                Cover(
                  image: item.image, eyebrow: "灵感示例 · 费用待沟通", title: item.title,
                  subtitle: item.summary, height: 170)
                VStack(alignment: .leading, spacing: 10) {
                  if let moment = item.steps.first { Text(moment).foregroundStyle(Ink.text) }
                  Text(item.experiences.joined(separator: " · ")).font(.travel(.footnote))
                    .foregroundStyle(Ink.muted)
                  Label("查看故事与可选体验", systemImage: "arrow.up.right.circle.fill").foregroundStyle(
                    Ink.accent)
                }.padding(16)
              }.frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.paper, in: RoundedRectangle(cornerRadius: 22)).contentShape(
                  Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(item.title).accessibilityHint("查看故事与可选体验")
              .accessibilityIdentifier("discovery.\(item.id)")
          }
        }
        MainButton("把灵感写进我的旅行", action: design)
      }
    }.navigationTitle("发现灵感")
  }
}

struct JourneyDetail: View {
  let item: Journey, open: (Route) -> Void
  @EnvironmentObject private var library: Library
  @State private var selected = Set<Int>()
  @State private var choosing = false
  @State private var consult = false
  @State private var problem: String?
  var body: some View {
    TravelPage {
      Cover(
        image: item.image, eyebrow: item.days == nil ? "A STORY TO KEEP" : "A JOURNEY IDEA",
        title: item.title, subtitle: "\(item.kind) · \(item.duration) · 费用待沟通", height: 280)
      Text(item.summary).font(.travel(.title3))
      if let needs = item.needs { Panel("这趟旅程，在意的是") { Text(needs) } }
      Panel(item.days == nil ? "旅程片段" : "沿途节奏") {
        ForEach(item.steps, id: \.self) { step in
          Text(step).frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      Panel("选择想带进心愿书的体验") {
        ForEach(item.experiences.indices, id: \.self) { i in
          Choice(title: item.experiences[i], selected: selected.contains(i)) {
            if selected.remove(i) == nil { selected.insert(i) }
          }
        }
      }
      if let included = item.included, let excluded = item.excluded {
        Panel("费用与服务说明") {
          Text(included)
          Divider()
          Text(excluded)
        }
      }
      Panel("参考条件") {
        Text(item.limits)
        Text("\(item.kind) · demo-1 · 费用待沟通").font(.travel(.footnote))
      }
      MainButton(item.days == nil ? "用这个故事开始设计" : "加入旅行参考") {
        consult = false
        choosing = true
      }.disabled(item.days == nil && selected.isEmpty)
      if item.days != nil {
        Button("咨询这个行程") {
          consult = true
          choosing = true
        }
      }
    }.navigationTitle(item.days == nil ? "故事详情" : "行程详情")
      .toolbar {
        Button {
          library.favorite(item.id)
        } label: {
          Image(systemName: library.data.favorites.contains(item.id) ? "heart.fill" : "heart")
        }.accessibilityLabel(library.data.favorites.contains(item.id) ? "取消收藏" : "收藏")
      }
      .sheet(isPresented: $choosing) {
        TravelSheetNavigation {
          List {
            Section("将所选体验加入心愿书") {
              ForEach(library.data.drafts) { draft in Button(draft.name) { importInto(draft) } }
              Button("新建旅行") { importInto(Draft(theme: item.theme)) }
            }
            if let problem { Text(problem).foregroundStyle(Ink.accent) }
          }.navigationTitle("选择一份草稿").toolbar { Button("取消") { choosing = false } }
        }.travelSheetSizes()
      }
  }
  private func importInto(_ original: Draft) {
    var draft = original
    guard draft.merge(item, selected: selected) else {
      problem = "最多添加 20 项，请先移除一项。"
      return
    }
    if !consult { draft.lastStep = 2 }
    guard library.save(draft) else { return }
    choosing = false
    problem = nil
    open(consult ? .book(draft.id) : .chapter(draft.id, 2, editing: false))
  }
}

struct LocalShelf: View {
  @EnvironmentObject var library: Library
  let open: (Route) -> Void
  @State private var deleting: Draft?
  var body: some View {
    TravelPage {
      Panel("我的草稿") {
        if library.data.drafts.isEmpty { Text("还没有旅行草稿，从一个心愿开始吧。") }
        ForEach(library.data.drafts) { d in
          Text(d.name).font(.travel(.body))
          Button("继续设计") { open(.chapter(d.id, d.lastStep, editing: false)) }
          Button("查看心愿书") { open(.book(d.id)) }
          Button("删除草稿", role: .destructive) { deleting = d }
          Divider()
        }
      }
      ForEach([false, true], id: \.self) { product in
        Panel(product ? "行程收藏" : "故事收藏") {
          let items = Catalog.items.filter {
            ($0.days != nil) == product && library.data.favorites.contains($0.id)
          }
          if items.isEmpty { Text("暂无收藏").foregroundStyle(Ink.muted) }
          ForEach(items) { item in
            Button(item.title) { open(.detail(item)) }
            Button("取消收藏") { library.favorite(item.id) }
          }
        }
      }
    }.navigationTitle("草稿与收藏")
      .alert(
        "删除这份本机草稿？",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        presenting: deleting
      ) { draft in
        Button("删除", role: .destructive) {
          var next = library.data
          next.drafts.removeAll { $0.id == draft.id }
          library.persist(next)
        }
        Button("取消", role: .cancel) {}
      } message: {
        Text("「\($0.name)」中的本机愿望将一并删除。")
      }
  }
}
struct RecordsPage: View {
  @EnvironmentObject private var library: Library
  var open: (Route) -> Void
  var body: some View {
    TravelPage {
      EmptyMessage("暂无提交记录", systemImage: "tray", description: Text("本机保存的心愿书可在草稿中查看。"))
      if !library.demoHistory.isEmpty {
        Panel("本机演示记录") {
          ForEach(library.demoHistory) { row in
            Button {
              open(.demoResult(row.id))
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(row.draft.name)
                Text(
                  "演示 · " + (row.outcome?.rawValue ?? "发送中") + " · "
                    + row.created.formatted(date: .omitted, time: .standard)
                )
                .font(.travel(.footnote))
              }
            }
          }
        }
      }
      Button("查看提交状态设计演示") { open(.receipt) }
    }.navigationTitle("提交记录")
  }
}
struct ReceiptExample: View {
  @State var state = "待确认"
  @State private var recovery = false
  let descriptions = [
    "发送中": "正在提交，请稍候…", "待确认": "暂未确认是否接收，请核验本次请求，不要重复提交。",
    "已接收": "接收编号：DEMO-RECEIPT-001\n接收时间：2026年11月18日 15:30（北京时间）", "未接收": "本次需求未接收",
    "本机记录保存失败": "需求已接收，但本机记录未保存成功，请恢复记录。",
  ]
  var body: some View {
    TravelPage {
      Panel("设计演示 · 提交状态") {
        Picker("状态", selection: $state) {
          ForEach(["发送中", "待确认", "已接收", "未接收", "本机记录保存失败"], id: \.self) { Text($0) }
        }
        Text(descriptions[state] ?? "")
        if state == "待确认" || state == "本机记录保存失败" {
          Button("查看原请求核验流程") { recovery = true }
        }
      }
      Panel("给妈妈的一次看海旅行") {
        Text("设计演示 · 只读快照")
        Text("3 位成人 · 0 位儿童 · 3 天 · 日期待沟通")
        Text("意向预算 CNY 9,000 · 全体预算")
        Text("轻松看海 · 一家人的合影 · 不赶时间的家宴")
      }
    }.navigationTitle("提交结果及需求详情")
      .sheet(isPresented: $recovery) {
        TravelSheetNavigation {
          TravelPage {
            Panel("正在核验的原请求") {
              Text("设计演示 · 给妈妈的一次看海旅行")
              Text("原手机号　1•• •••• ••••")
              Text("请验证提交时使用的手机号。这不会再次提交旅行需求。")
            }
            Panel("验证本人手机号") {
              Text("咨询服务尚未配置。")
              Button("获取验证码") {}.disabled(true)
              Button("验证并核验原请求") {}.disabled(true)
            }
          }.navigationTitle("核验原请求").toolbar { Button("返回") { recovery = false } }
        }
      }
  }
}
struct HelpPage: View {
  @State private var confirm = false
  @EnvironmentObject private var library: Library
  var body: some View {
    TravelPage {
      Panel("帮助与隐私") {
        DisclosureGroup("草稿保存在哪里？") { Text("草稿仅保存在这台设备上，暂不支持跨设备同步。") }
        DisclosureGroup("提交后就是预订成功吗？") { Text("提交咨询不代表预订成功。") }
        DisclosureGroup("如何申请删除已提交资料？") { Text("需要通过实际受理渠道提出请求。当前受理渠道尚未配置。") }
      }
      Panel("服务说明") { Text("服务主体、隐私政策与受理渠道尚未配置。咨询服务暂不可用。") }
      Button("清空本机数据", role: .destructive) { confirm = true }
    }.navigationTitle("帮助与隐私")
      .confirmationDialog("清空本机的草稿及收藏？", isPresented: $confirm, titleVisibility: .visible) {
        Button("清空本机数据", role: .destructive) { library.clearLocalData() }
        Button("取消", role: .cancel) {}
      } message: {
        Text("仅删除本机内容，不会撤回或删除已提交的后台需求。")
      }
  }
}
