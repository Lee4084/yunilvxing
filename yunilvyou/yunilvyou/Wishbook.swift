import SwiftUI

struct Wishbook: View {
  @Binding var draft: Draft
  var open: (Route) -> Void
  @State private var checking = false
  @State private var correction: Int?
  @FocusState private var editingTitle: Bool
  var body: some View {
    TravelPage {
      Cover(
        image: draft.theme.map { Catalog.themeCovers[$0] } ?? "welcome", eyebrow: "YOUR TRAVEL WISHBOOK",
        title: draft.name, subtitle: "这是一份旅行愿望，具体安排需沟通确认。")
      Panel("心愿书封面") {
        LabeledInput(label: "心愿书标题", text: $draft.title, limit: 40).focused($editingTitle)
        TravelMenu(title: "封面主题", value: draft.theme.map { Catalog.themes[$0] } ?? "通用封面") {
          Button("通用封面") { draft.theme = nil }
          ForEach(Catalog.themes.indices, id: \.self) { i in
            Button(Catalog.themes[i]) { draft.theme = i }
          }
        }
      }
      ForEach(Catalog.chapters.indices, id: \.self) { index in
        Panel(Catalog.chapters[index]) {
          Text(draft.chapterSummary(index))
          Button("编辑" + Catalog.chapters[index]) { open(.chapter(draft.id, index, editing: true)) }
        }
      }
      MainButton("提交行程愿望单") {
        guard draft.ready else { checking = true; return }
        open(.contact(draft.id))
      }
    }.navigationTitle("旅行心愿书")
      .sheet(
        isPresented: $checking,
        onDismiss: {
          guard let correction else { return }
          self.correction = nil
          if correction < 0 {
            editingTitle = true
          } else {
            open(.chapter(draft.id, correction, editing: true))
          }
        }
      ) {
        TravelSheetNavigation {
          List {
            ForEach([0, 1, 2, 4].filter { !draft.completed[$0] }, id: \.self) { index in
              Button {
                correction = index
                checking = false
              } label: {
                Label(missing(index), systemImage: "pencil").frame(minHeight: 52)
              }
            }
            if !draft.note.optionalValid(300) {
              Button("检查舒适偏好的补充说明") {
                correction = 3
                checking = false
              }
            }
            if !draft.title.optionalValid(40) {
              Button("修改标题（最多 40 个字符）") {
                correction = -1
                checking = false
              }
            }
          }.navigationTitle("咨询前还需补充").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("返回心愿书") { checking = false } }
        }.font(.travel(.body)).travelSheetSizes()
      }
  }
  private func missing(_ index: Int) -> String {
    switch index {
    case 0: return draft.relations.isEmpty ? "选择同行关系" : "检查自定义关系或昵称"
    case 1: return draft.reason.isEmpty ? "选择出发的理由" : "检查自定义理由或寄语"
    case 2: return draft.wishes.isEmpty ? "添加至少一项愿望" : "选择优先愿望，或选「暂不区分优先级」"
    default:
      if draft.adults == nil || draft.children == nil { return "填写成人和儿童人数（没有儿童请选择 0 人）" }
      if !draft.partyValid { return "检查同行人数，总计最多 99 人" }
      return "检查出发日期和地点意向"
    }
  }
}

extension Draft {
  func chapterSummary(_ index: Int) -> String {
    let draft = self
    let lines: [String]
    switch index {
    case 0:
      lines = draft.relations.map { $0 == "自定义" ? draft.customRelation : $0 } + [draft.nickname]
    case 1: lines = [draft.reason == "自定义" ? draft.customReason : draft.reason, draft.message]
    case 2:
      lines =
        draft.wishes.map { wish in
          if let p = draft.priority.firstIndex(of: wish.id) { return "优先 \(p+1) · \(wish.title)" }
          return wish.title
        } + (draft.equal ? ["暂不区分优先级"] : [])
    case 3:
      lines =
        draft.noPreferences
        ? ["暂无特别要求"]
        : draft.preferences.keys.sorted().map { "\($0) · \(draft.preferences[$0]!)" }
          + draft.avoids.map { "避开 · " + $0 } + [draft.note]
    default:
      lines = [
        draft.dateSummary, draft.adults.map { "\($0) 位成人" } ?? "成人数待填写",
        draft.children.map { "\($0) 位儿童" } ?? "儿童数待填写", draft.budgetSummary,
        draft.destination.trimmed.isEmpty ? "地点待沟通" : draft.destination,
      ]
    }
    let text = lines.filter { !$0.isEmpty }.joined(separator: "\n")
    return text.isEmpty ? "待沟通" : text
  }
}

struct ContactPreferencePanel: View {
  @Binding var preferences: ContactPreferences
  var body: some View {
    Panel("咨询偏好") {
      TravelMenu(title: "希望如何联系你", value: preferences.channel.isEmpty ? "未选择" : preferences.channel)
      {
        ForEach(["未选择", "电话联系", "短信联系", "电话或短信均可"], id: \.self) { value in
          Button(value) { preferences.channel = value == "未选择" ? "" : value }
        }
      }
      TravelMenu(title: "方便联系的时间", value: preferences.time.isEmpty ? "未选择" : preferences.time) {
        ForEach(["未选择", "上午 09:00–12:00", "下午 14:00–18:00", "晚间 18:00–20:00", "自定义时间"], id: \.self)
        { value in
          Button(value) { preferences.time = value == "未选择" ? "" : value }
        }
      }
      if preferences.time == "自定义时间" {
        LabeledInput(label: "自定义时间", text: $preferences.customTime, limit: 100)
      }
      Toggle("这是一次惊喜，请只联系我", isOn: $preferences.surprise).frame(minHeight: 52)
      Text("偏好保存在本机，准备咨询时可继续修改。").font(.travel(.footnote)).foregroundStyle(Ink.muted)
    }
  }
}
