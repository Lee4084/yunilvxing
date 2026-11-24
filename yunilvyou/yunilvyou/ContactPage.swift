import SwiftUI

struct ContactPage: View {
  let draft: Draft
  let submitted: (UUID) -> Void
  @EnvironmentObject private var library: Library
  @EnvironmentObject private var account: TravelAccount
  @State private var agreed = false
  @State private var sending = false
  @State private var retryAfter = Date.distantPast
  @State private var status = ""

  var body: some View {
    TravelPage {
      Panel(draft.name) {
        Text(draft.dateSummary)
        Text("\(draft.wishes.count) 项愿望 · \(draft.budgetSummary)")
      }
      ContactPreferencePanel(preferences: library.contactBinding).disabled(sending)
      Panel("本次提交") {
        if let phone = account.session?.login.appUser.maskedPhone {
          Label("联系号码  " + phone, systemImage: "checkmark.circle")
        }
        #if DEBUG
        Text("这份心愿书、联系偏好和登录手机号将一并提交至予你旅行测试后台。")
        #else
        Text("我们将按你选择的方式，通过登录手机号与你联系。")
        #endif
        AgreementLinks(documents: [.privacy])
        Toggle("同意提交本次愿望单与联系方式", isOn: $agreed).disabled(sending)
      }
      if !status.isEmpty {
        Text(status).font(.travel(.subheadline)).accessibilityIdentifier("wishbook.requestStatus")
      }
      TimelineView(.periodic(from: .now, by: 1)) { tick in
        let wait = max(0, Int(ceil(retryAfter.timeIntervalSince(tick.date))))
        MainButton(sending ? "正在提交…" : wait > 0 ? "\(wait) 秒后可提交" : "确认提交行程愿望单") { submit() }
          .disabled(sending || wait > 0 || !agreed || !draft.ready || account.session == nil)
      }
    }.navigationTitle("联系与提交确认")
      .navigationBarBackButtonHidden(sending)
  }

  private func submit() {
    guard !sending, retryAfter <= Date(), agreed, draft.ready, account.session != nil else { return }
    let text = draft.submissionText(contact: library.data.contactPreferences ?? ContactPreferences())
    sending = true
    status = "正在提交行程愿望单…"
    Task {
      defer { sending = false }
      do {
        let result = try await account.submit(draftID: draft.id, text: text)
        library.record(WishReceipt(id: result.submissionId, name: draft.name, submittedAt: result.submittedAt))
        submitted(result.submissionId)
      } catch let issue as WishServiceError {
        if case let .rateLimited(seconds?, _) = issue {
          retryAfter = Date().addingTimeInterval(TimeInterval(seconds))
        }
        status = issue.localizedDescription
      } catch {
        status = "尚未确认后台是否收到。请保留原内容并重试，可核对同一次提交。"
      }
    }
  }
}

extension Draft {
  func submissionText(contact: ContactPreferences) -> String {
    var sections = [name]
    if let theme, Catalog.themes.indices.contains(theme) { sections.append("封面主题：" + Catalog.themes[theme]) }
    for (index, label) in Catalog.chapters.enumerated() {
      sections.append(label + "：" + chapterSummary(index))
    }
    if !references.isEmpty {
      sections.append("参考灵感：" + references.map { id in Catalog.items.first { $0.id == id }?.title ?? id }.joined(separator: "、"))
    }
    if !contact.channel.isEmpty { sections.append("联系渠道：" + contact.channel) }
    if !contact.time.isEmpty {
      sections.append("联系时间：" + (contact.time == "自定义时间" ? contact.customTime : contact.time))
    }
    if contact.surprise { sections.append("这是一次惊喜，请只联系我。") }
    return sections.joined(separator: "\n\n")
  }
}
