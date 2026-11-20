import SwiftUI

enum DemoOutcome: String, CaseIterable {
  case accepted = "已接收"
  case unknown = "待确认"
  case rejected = "未接收"
}

struct DemoConsultation: Identifiable {
  static let phone = "DEMO-0001"
  let id = UUID()
  let draft: Draft
  let created = Date()
  var outcome: DemoOutcome?

  var homeStatus: String {
    switch outcome {
    case nil: return "正在模拟提交…"
    case .accepted: return "模拟需求已接收"
    case .unknown: return "模拟提交结果待确认"
    case .rejected: return "模拟需求未接收"
    }
  }

  static let example: Draft = {
    var draft = Draft(title: "给妈妈的一次看海旅行", theme: 2)
    draft.adults = 3
    draft.children = 0
    draft.days = 3
    draft.budget = 9000
    draft.scope = "全体预算"
    if let story = Catalog.items.first(where: { $0.id == "YN-S05" }) {
      _ = draft.merge(story, selected: [0, 1, 2])
      draft.priority = Array(draft.wishes.prefix(2).map(\.id))
    }
    return draft
  }()
}

struct DemoConsultationForm: View {
  @EnvironmentObject private var library: Library
  let draft: Draft
  let submitted: (UUID) -> Void
  @State private var outcome: DemoOutcome = .accepted
  @State private var verified = false
  @State private var agreed = false
  @State private var request: UUID?

  var body: some View {
    TravelPage {
      Panel("本机演示 · 咨询确认") {
        Text(draft.name).font(.travel(.title2))
        Text(draft.dateSummary)
        Text("使用虚拟号码体验提交和回执。演示记录只在本次打开 App 期间保留。")
          .font(.travel(.footnote)).foregroundStyle(Ink.muted)
      }
      Panel("虚拟号码") {
        Text(DemoConsultation.phone).font(.travel(.title2))
        if verified {
          Label("虚拟号码已模拟验证", systemImage: "checkmark.circle.fill")
        } else {
          Button("模拟验证号码") { verified = true }
        }
      }
      Panel("提交设置") {
        TravelMenu(title: "模拟提交后的结果", value: outcome.rawValue) {
          ForEach(DemoOutcome.allCases, id: \.self) { state in
            Button(state.rawValue) { outcome = state }
          }
        }
        Button {
          agreed.toggle()
        } label: {
          HStack {
            Text("我确认体验本机模拟提交")
            Spacer()
            Toggle("", isOn: .constant(agreed)).labelsHidden().allowsHitTesting(false)
          }
          .frame(minHeight: 52)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle("我确认体验本机模拟提交", isOn: $agreed) }
      }
      MainButton("模拟提交我的旅行需求") {
        guard request == nil else { return }
        let id = library.simulate(draft: draft, outcome: outcome)
        request = id
        submitted(id)
      }.disabled(!verified || !agreed || request != nil)
      if !verified || !agreed { Text("请先模拟验证号码，并确认体验本机提交。").font(.travel(.footnote)) }
    }.navigationTitle("模拟咨询")
  }
}

struct DemoResultPage: View {
  @EnvironmentObject private var library: Library
  let id: UUID
  let open: (Route) -> Void
  var body: some View {
    TravelPage {
      if let record = library.demoHistory.first(where: { $0.id == id }) {
        Panel("本机演示 · 提交结果") {
          switch record.outcome {
          case nil:
            ProgressView("正在模拟提交…")
          case .accepted:
            Label("模拟需求已接收", systemImage: "checkmark.circle.fill").font(.travel(.title2))
            Text("示例回执　DEMO-RECEIPT-001")
          case .unknown:
            Label("模拟提交结果待确认", systemImage: "clock")
            MainButton("模拟核验本次请求") { library.finishDemo(id, as: .accepted) }
          case .rejected:
            Label("模拟需求未接收", systemImage: "exclamationmark.circle")
            Text("可返回演示入口重新体验。")
          }
          Text("本机演示时间　" + record.created.formatted(date: .abbreviated, time: .shortened))
            .font(.travel(.footnote))
        }
        Panel("本次心愿书快照") {
          Text(record.draft.name).font(.travel(.title2))
          Text("虚拟号码　" + DemoConsultation.phone)
          Text(record.draft.dateSummary)
          Text(record.draft.budgetSummary)
          if !record.draft.wishes.isEmpty {
            Text(record.draft.wishes.map(\.title).joined(separator: " · "))
          }
        }
        Button("查看本机演示记录") { open(.records) }.buttonStyle(PanelActionStyle())
      }
    }.navigationTitle("模拟提交结果")
  }
}
