import SwiftUI

enum PlanConsultationStage: Equatable {
  case ready, finished(String)
}

struct CityPlanConsultation: View {
  let plan: CityPlan
  @Binding var stage: PlanConsultationStage
  @EnvironmentObject private var account: TravelAccount
  @EnvironmentObject private var library: Library
  @Environment(\.dismiss) private var dismiss
  @State private var requestID = UUID()
  @State private var agreed = false
  @State private var sending = false
  @State private var status = ""
  @State private var retryAfter = Date.distantPast

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("方案咨询").font(.travel(.title2)).accessibilityAddTraits(.isHeader)
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark").frame(width: 44, height: 44)
        }.accessibilityLabel("关闭咨询").disabled(sending)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 10) {
            coverImage(plan.cover + "-cover").resizable().scaledToFill()
              .frame(width: 54, height: 60).clipped().cornerRadius(8).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
              Text(plan.title).font(.travel(.headline))
              Text("\(plan.city) · \(plan.number)号方案").font(.travel(.footnote))
            }
          }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: 14))
          if case .finished(let phone) = stage {
            reply("收到您想了解的行程啦，谢谢您的信任。")
            Text("联系号码 " + phone).padding(12)
              .frame(maxWidth: .infinity, alignment: .trailing)
            reply("我们会通过您的登录号码与您联系，请留意来电。期待和您一起聊聊这趟旅行。")
          } else {
            Text("发送后，我们将通过您的登录手机号与您联系，一起聊聊这趟旅行。")
            if let phone = account.session?.login.appUser.maskedPhone {
              Label("联系号码 " + phone, systemImage: "phone")
            }
            Toggle("同意将当前方案和登录号码用于本次咨询", isOn: $agreed).disabled(sending)
            AgreementLinks(documents: [.privacy])
          }
          if !status.isEmpty {
            Text(status).font(.travel(.footnote)).foregroundStyle(Ink.accent)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      if stage == .ready {
        TimelineView(.periodic(from: .now, by: 1)) { tick in
          let wait = max(0, Int(ceil(retryAfter.timeIntervalSince(tick.date))))
          MainButton(sending ? "正在发送…" : wait > 0 ? "\(wait) 秒后可重试" : "发送方案咨询") { send() }
            .disabled(sending || !agreed || account.session == nil || wait > 0)
        }
      }
    }.padding(16).background(Ink.canvas).foregroundStyle(Ink.text).font(.travel(.body))
      .interactiveDismissDisabled(sending)
  }

  private func reply(_ text: String) -> some View {
    Text(text).padding(12).background(Ink.paper, in: RoundedRectangle(cornerRadius: 14))
  }

  private func send() {
    guard !sending, agreed, account.session != nil, retryAfter <= Date() else { return }
    sending = true
    status = ""
    let text = "城市旅行方案咨询\n方案编号：\(plan.id)\n城市：\(plan.city)\n方案：\(plan.title)\n说明：\(plan.summary)\n同意使用登录号码联系。"
    Task {
      defer { sending = false }
      do {
        let result = try await account.submit(draftID: requestID, text: text)
        library.record(WishReceipt(id: result.submissionId, name: "方案咨询 · " + plan.title,
          submittedAt: result.submittedAt))
        stage = .finished(account.session?.login.appUser.maskedPhone ?? "已验证的登录号码")
      } catch let issue as WishServiceError {
        if case let .rateLimited(seconds?, _) = issue {
          retryAfter = Date().addingTimeInterval(TimeInterval(seconds))
        }
        status = issue.localizedDescription
      } catch {
        status = "暂未确认是否发送成功，请稍后重试。"
      }
    }
  }
}
