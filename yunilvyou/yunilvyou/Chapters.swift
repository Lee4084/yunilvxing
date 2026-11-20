import SwiftUI

enum EditorSheet: String, Identifiable {
  case wish, dates, budget
  var id: Self { self }
}
struct ChapterView: View {
  @Binding var draft: Draft
  let step: Int, editing: Bool, advance: (Int) -> Void, jump: (Int) -> Void, exit: () -> Void
  @State private var sheet: EditorSheet?
  @State private var confirm: String?
  @State private var pendingAction: (() -> Void)?
  @State private var warning: String?
  private let preferenceOptions = [
    ("旅行节奏", ["慢慢享受", "适中安排", "充实一些", "暂无偏好"]),
    ("步行安排", ["尽量少走路", "适量步行", "愿意多走走", "待沟通"]),
    ("住宿偏好", ["安静舒适", "有景观特色", "方便出行", "暂无偏好"]),
    ("饮食偏好", ["清淡一些", "体验当地味道", "更熟悉的口味", "待沟通"]),
  ]
  var body: some View {
    TravelPage {
      VStack(alignment: .leading, spacing: 10) {
        Menu {
          ForEach(Catalog.chapters.indices, id: \.self) { i in
            Button(Catalog.chapters[i]) { if i != step { jump(i) } }
          }
        } label: {
          Label("第 \(step + 1) / 5 章", systemImage: "list.bullet").font(
            .travel(.subheadline))
        }
        Text(Catalog.chapters[step]).font(.travel(.largeTitle))
        ProgressView(value: Double(step + 1), total: 5)
      }
      switch step {
      case 0: relationPage
      case 1: reasonPage
      case 2: wishesPage
      case 3: preferencesPage
      default: conditionsPage
      }
      MainButton(editing ? "完成，返回心愿书" : step == 4 ? "查看旅行心愿书" : "下一章") {
        let valid = [
          draft.nickname.optionalValid(20) && draft.customRelation.optionalValid(100),
          draft.customReason.optionalValid(100) && draft.message.optionalValid(300),
          true, draft.note.optionalValid(300),
          draft.destination.optionalValid(100) && (draft.adults ?? 0) + (draft.children ?? 0) <= 99,
        ]
        if valid[step] { advance(step + 1) } else { warning = "请先检查本章已填写的字段。" }
      }
      Button("保存并返回") { if editing { advance(step) } else { exit() } }
    }.id(step).navigationTitle("旅行心愿书")
      .onAppear { if draft.lastStep != step { draft.lastStep = step } }
      .confirmationDialog(
        confirm ?? "",
        isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
        titleVisibility: .visible
      ) {
        Button("确认", role: .destructive) {
          pendingAction?()
          pendingAction = nil
        }
        Button("取消", role: .cancel) { pendingAction = nil }
      }
      .alert(
        warning ?? "",
        isPresented: Binding(get: { warning != nil }, set: { if !$0 { warning = nil } })
      ) { Button("好") {} }
      .sheet(item: $sheet) { editor in
        ChapterEditor(draft: $draft, editor: editor).travelSheetSizes()
      }
  }
  private func ask(_ message: String, _ action: @escaping () -> Void) {
    pendingAction = action
    confirm = message
  }
  @ViewBuilder private var relationPage: some View {
    Panel("这次旅程想和谁一起？") {
      ForEach(["为自己", "爱人", "父母", "朋友", "家人", "自定义"], id: \.self) { value in
        Choice(title: value, selected: draft.relations.contains(value)) {
          if !draft.relations.contains(value) {
            draft.relations.append(value)
          } else if value == "自定义" && !draft.customRelation.isEmpty {
            ask("清空自定义关系？") {
              draft.customRelation = ""
              draft.relations.removeAll { $0 == value }
            }
          } else {
            draft.relations.removeAll { $0 == value }
          }
        }
      }
      if draft.relations.contains("自定义") {
        LabeledInput(label: "自定义关系", text: $draft.customRelation, limit: 100)
      }
    }
    Panel("同行的人") { LabeledInput(label: "昵称（选填）", text: $draft.nickname, limit: 20) }
  }
  @ViewBuilder private var reasonPage: some View {
    Panel("这次出发的特别理由") {
      ForEach(["生日", "周年纪念", "毕业", "感谢", "实现心愿", "没有固定纪念日", "自定义"], id: \.self) { value in
        Choice(title: value, selected: draft.reason == value) {
          if draft.reason == "自定义" && !draft.customReason.isEmpty && value != "自定义" {
            ask("更换理由并清空自定义理由？") {
              draft.customReason = ""
              draft.reason = value
            }
          } else {
            draft.reason = value
          }
        }
      }
      if draft.reason == "自定义" {
        LabeledInput(label: "自定义理由", text: $draft.customReason, limit: 100)
      }
    }
    Panel("想说的话") { LabeledInput(label: "寄语（选填）", text: $draft.message, limit: 300) }
  }
  @ViewBuilder private var wishesPage: some View {
    Panel("已选 \(draft.wishes.count) / 20 项") {
      ForEach(draft.wishes) { wish in
        VStack(alignment: .leading) {
          Choice(title: wish.title, selected: draft.priority.contains(wish.id)) {
            if draft.priority.contains(wish.id) {
              draft.priority.removeAll { $0 == wish.id }
            } else if draft.priority.count < 3 {
              draft.priority.append(wish.id)
              draft.equal = false
            } else {
              warning = "最多标记 3 项最重要的愿望。"
            }
          }.accessibilityHint("标记或取消最重要的愿望")
          if let rank = draft.priority.firstIndex(of: wish.id) {
            Text("优先 \(rank+1)").font(.travel(.caption))
          }
          HStack {
            Button("上移") { move(wish, -1) }.disabled(draft.wishes.first == wish)
            Button("下移") { move(wish, 1) }.disabled(draft.wishes.last == wish)
            Spacer()
            Button("移除", role: .destructive) {
              ask("移除「\(wish.title)」？") {
                draft.wishes.removeAll { $0.id == wish.id }
                draft.priority.removeAll { $0 == wish.id }
              }
            }
          }.font(.travel(.subheadline)).frame(minHeight: 44)
        }
        Divider()
      }
      Text("点选最多 3 项最重要的愿望。").font(.travel(.footnote))
      Choice(title: "暂不区分优先级", selected: draft.equal) {
        draft.equal.toggle()
        draft.priority = []
      }
      Button("添加自己的愿望") { sheet = .wish }.disabled(draft.wishes.count >= 20)
    }
    Panel("旅行体验") {
      ForEach(Catalog.items.filter { $0.days == nil }) { item in
        DisclosureGroup(item.title) {
          ForEach(item.experiences.indices, id: \.self) { i in
            Button(item.experiences[i]) {
              if !draft.merge(item, selected: [i]) { warning = "最多添加 20 项，请先移除一项。" }
            }.disabled(draft.wishes.contains { $0.id == "\(item.id)-E\(i+1)" })
          }
        }
      }
    }
  }
  private func move(_ wish: Wish, _ direction: Int) {
    guard let index = draft.wishes.firstIndex(of: wish),
      draft.wishes.indices.contains(index + direction)
    else { return }
    draft.wishes.swapAt(index, index + direction)
    let top = Set(draft.priority)
    draft.priority = draft.wishes.map(\.id).filter(top.contains)
  }
  @ViewBuilder private var preferencesPage: some View {
    Panel("舒适偏好") {
      Choice(title: "暂无特别要求", selected: draft.noPreferences) {
        if draft.noPreferences {
          draft.noPreferences = false
        } else if !draft.preferences.isEmpty || !draft.avoids.isEmpty || !draft.note.isEmpty {
          ask("清空节奏、步行、住宿、饮食、避开事项和补充说明？") {
            draft.preferences = [:]
            draft.avoids = []
            draft.note = ""
            draft.noPreferences = true
          }
        } else {
          draft.noPreferences = true
        }
      }
      if !draft.noPreferences {
        ForEach(preferenceOptions.indices, id: \.self) { i in
          let (label, options) = preferenceOptions[i]
          TravelMenu(title: label, value: draft.preferences[label] ?? "未选择") {
            Button("未选择") { draft.preferences[label] = nil }
            ForEach(options, id: \.self) { value in
              Button(value) { draft.preferences[label] = value }
            }
          }
        }
      }
    }
    if !draft.noPreferences {
      Panel("不想安排的内容") {
        ForEach(["购物安排", "太早出发", "长时间步行", "安排太满", "其他"], id: \.self) { item in
          Choice(title: item, selected: draft.avoids.contains(item)) {
            if draft.avoids.contains(item) {
              draft.avoids.removeAll { $0 == item }
            } else {
              draft.avoids.append(item)
            }
          }
        }
        LabeledInput(label: "补充说明", text: $draft.note, limit: 300)
      }
    }
  }
  @ViewBuilder private var conditionsPage: some View {
    Panel("日期与天数") {
      Text(draft.dateSummary)
      Button("编辑日期与天数") { sheet = .dates }
    }
    Panel("同行人数") {
      numberPicker("成人人数", range: 1...99, value: $draft.adults)
      numberPicker("儿童人数", range: 0...99, value: $draft.children)
      if let a = draft.adults, let c = draft.children, a + c > 99 {
        Text("至少 1 位成年人，总人数不超过 99 人。").foregroundStyle(Ink.accent)
      }
    }
    Panel("意向预算") {
      Text(draft.budgetSummary)
      Button("编辑预算") { sheet = .budget }
    }
    Panel("地点意向") { LabeledInput(label: "希望去哪里（选填）", text: $draft.destination, limit: 100) }
  }
  private func numberPicker(_ title: String, range: ClosedRange<Int>, value: Binding<Int?>)
    -> some View
  {
    TravelMenu(title: title, value: value.wrappedValue.map { "\($0) 人" } ?? "请选择人数") {
      Picker(title, selection: value) {
        Text("未填写").tag(Int?.none)
        ForEach(range, id: \.self) { Text("\($0) 人").tag(Optional($0)) }
      }.pickerStyle(.inline)
    }
  }
}

extension Draft {
  var dateSummary: String {
    var result = start.map { TravelDates.display($0) } ?? "日期待沟通"
    if let end { result += " 至 " + TravelDates.display(end) }
    return result + " · " + (days.map { "\($0) 天" } ?? "天数待沟通")
  }
  var budgetSummary: String {
    guard let budget, let scope else { return "预算待沟通" }
    return "\(scope) · CNY \(budget)"
  }
}

struct ChapterEditor: View {
  @Environment(\.dismiss) var dismiss
  @Binding var draft: Draft
  let editor: EditorSheet
  @State private var text = ""
  @State private var mode = "待沟通"
  @State private var scope = ""
  @State private var days = ""
  @State private var start = Date.now
  @State private var end = Date.now
  @State private var error = ""
  @State private var clearing = false
  var body: some View {
    TravelSheetNavigation {
      Form {
        switch editor {
        case .wish: LabeledInput(label: "愿望内容", text: $text, limit: 100)
        case .dates:
          Picker("出发日期", selection: $mode) {
            ForEach(["待沟通", "确定出发日", "时间有弹性"], id: \.self) { Text($0) }
          }
          if mode != "待沟通" { DatePicker("最早出发日", selection: $start, displayedComponents: .date) }
          if mode == "时间有弹性" { DatePicker("最晚出发日", selection: $end, displayedComponents: .date) }
          TextField("旅行天数（1–90，可留空）", text: $days).keyboardType(.numberPad)
        case .budget:
          Picker("预算", selection: $mode) {
            Text("待沟通").tag("待沟通")
            Text("填写预算").tag("填写预算")
          }
          if mode != "待沟通" {
            TextField("意向预算金额（CNY）", text: $text).keyboardType(.decimalPad)
            Picker("预算口径", selection: $scope) {
              ForEach(["", "每人预算", "全体预算"], id: \.self) { Text($0.isEmpty ? "请选择" : $0).tag($0) }
            }
          }
        }
        if !error.isEmpty { Text(error).foregroundStyle(Ink.accent) }
        Button("确认") {
          if mode == "待沟通"
            && ((editor == .dates && draft.start != nil)
              || (editor == .budget && draft.budget != nil))
          {
            clearing = true
          } else {
            commit()
          }
        }
      }.environment(\.defaultMinListRowHeight, 54).environment(
        \.timeZone, TravelDates.calendar.timeZone
      ).navigationTitle(
        editor == .wish ? "添加自己的愿望" : editor == .dates ? "日期与天数" : "意向预算"
      )
      .toolbar { Button("取消") { dismiss() } }
      .onAppear {
        if editor == .dates {
          start = draft.start ?? .now
          end = draft.end ?? start
          mode = draft.start == nil ? "待沟通" : draft.end == nil ? "确定出发日" : "时间有弹性"
          days = draft.days.map(String.init) ?? ""
        } else if editor == .budget, let amount = draft.budget {
          mode = "填写预算"
          text = "\(amount)"
          scope = draft.scope ?? ""
        }
      }.confirmationDialog(
        editor == .dates ? "清空已填写的出发日期？" : "清空预算金额和口径？", isPresented: $clearing,
        titleVisibility: .visible
      ) {
        Button("确认清空", role: .destructive) { commit() }
        Button("取消", role: .cancel) {}
      }
    }
  }
  func commit() {
    var next = draft
    switch editor {
    case .wish:
      guard text.valid(100), draft.wishes.count < 20 else {
        error = "请输入 1–100 个字符，最多添加 20 项愿望。"
        return
      }
      let key = "custom-" + text.trimmed
      guard !draft.wishes.contains(where: { $0.id == key }) else {
        error = "这项体验已在心愿书中。"
        return
      }
      next.wishes.append(Wish(id: key, title: text.trimmed))
    case .dates:
      let count = Int(days)
      guard days.isEmpty || (1...90).contains(count ?? 0) else {
        error = "旅行天数请输入 1–90 天。"
        return
      }
      let calendar = TravelDates.calendar
      if mode != "待沟通" && start < calendar.startOfDay(for: .now) {
        error = "出发日期已过去。"
        return
      }
      if mode == "时间有弹性" && calendar.startOfDay(for: end) < calendar.startOfDay(for: start) {
        error = "最晚出发日不能早于最早出发日。"
        return
      }
      next.days = count
      next.start = mode == "待沟通" ? nil : calendar.startOfDay(for: start)
      next.end = mode == "时间有弹性" ? calendar.startOfDay(for: end) : nil
    case .budget:
      if mode == "待沟通" {
        next.budget = nil
        next.scope = nil
      } else {
        guard text.range(of: "^[0-9]+(\\.[0-9]{1,2})?$", options: .regularExpression) != nil,
          let amount = Decimal(string: text), amount >= 1, amount <= 1_000_000, !scope.isEmpty
        else {
          error = "请输入有效预算并选择每人或全体。"
          return
        }
        next.budget = amount
        next.scope = scope
      }
    }
    draft = next
    dismiss()
  }
}
