import SwiftUI

enum PlanConsultationStage: Equatable {
  case ready, awaitingPhone, finished(String)

  static func phoneSuffix(_ input: String) -> String? {
    let compact = input.filter { !$0.isWhitespace && !"()-".contains($0) }
    let digits = compact.hasPrefix("+") ? compact.dropFirst() : compact[...]
    guard (7...15).contains(digits.count),
          digits.allSatisfy({ "0123456789".contains($0) }) else { return nil }
    return String(digits.suffix(4))
  }
}

struct CityPlanConsultation: View {
  let plan: CityPlan
  @Binding var stage: PlanConsultationStage
  @State private var phone = ""
  @State private var invalid = false
  @FocusState private var typing: Bool
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("方案咨询").font(.travel(.title2)).accessibilityAddTraits(.isHeader)
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark").frame(width: 44, height: 44)
        }.accessibilityLabel("关闭咨询")
      }
      Text("本机演示 · 可用 00000000000 体验，无实际回电")
        .font(.travel(.footnote)).foregroundStyle(Ink.muted)
      ScrollViewReader { reader in
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
              coverImage(plan.cover + "-cover").resizable().scaledToFill()
                .frame(width: 54, height: 60).clipped().cornerRadius(8).accessibilityHidden(true)
              VStack(alignment: .leading, spacing: 4) {
                Text(plan.title).font(.travel(.headline))
                Text("\(plan.city) · \(plan.number)号方案").font(.travel(.footnote))
              }
              Spacer(minLength: 2)
              if stage == .ready {
                Button("发送") { stage = .awaitingPhone }
                  .frame(minWidth: 44, minHeight: 44).buttonStyle(.borderedProminent)
                  .accessibilityHint("发送当前方案")
              }
            }.padding(12).background(Ink.paper, in: RoundedRectangle(cornerRadius: 14))
            if stage != .ready {
              reply("收到您想了解的行程啦。方便留个联系电话吗？我们会尽快联系您，一起聊聊这趟旅行。")
            }
            if case .finished(let suffix) = stage {
              Text("联系电话 · 尾号 " + suffix).padding(12)
                .background(Ink.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: .infinity, alignment: .trailing)
              reply("谢谢您留下号码，稍后请留意来电。期待听听您对这趟旅行的想法。").id("lastReply")
            }
          }.frame(maxWidth: .infinity, alignment: .leading)
        }.onChange(of: stage) { value in
          if case .finished = value { reader.scrollTo("lastReply", anchor: .bottom) }
        }
      }
      if stage == .awaitingPhone {
        if invalid { Text("请输入有效的联系电话。").font(.travel(.footnote)).foregroundStyle(Ink.accent) }
        HStack {
          TextField("联系电话", text: $phone).textFieldStyle(.roundedBorder)
            .keyboardType(.phonePad).focused($typing)
            .onChange(of: phone) { _ in invalid = false }
          Button("发送") {
            guard let suffix = PlanConsultationStage.phoneSuffix(phone) else { invalid = true; return }
            typing = false
            phone = ""
            stage = .finished(suffix)
          }.frame(minWidth: 44, minHeight: 44).buttonStyle(.borderedProminent)
            .accessibilityHint("发送联系电话")
        }
      }
    }.padding(16).background(Ink.canvas).foregroundStyle(Ink.text).font(.travel(.body))
  }

  private func reply(_ text: String) -> some View {
    Text(text).padding(12).background(Ink.paper, in: RoundedRectangle(cornerRadius: 14))
  }
}
