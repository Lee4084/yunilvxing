import SwiftUI

struct AccountPanel: View {
  @EnvironmentObject private var account: TravelAccount
  @State private var confirmingLogout = false
  @State private var loggingOut = false
  @State private var logoutError: String?

  var body: some View {
      Panel("账号") {
        if let number = account.session?.login.appUser.maskedPhone { Text(number) }
        Button(role: .destructive) { confirmingLogout = true } label: {
          HStack {
            Label(loggingOut ? "正在退出…" : "退出登录", systemImage: "rectangle.portrait.and.arrow.right")
            Spacer()
            if loggingOut { ProgressView() }
          }.frame(minHeight: 44)
        }.disabled(loggingOut).accessibilityIdentifier("account.logout")
      }

    .confirmationDialog("退出当前账号？", isPresented: $confirmingLogout, titleVisibility: .visible) {
      Button("退出登录", role: .destructive) {
        loggingOut = true
        Task {
          defer { loggingOut = false }
          do { try await account.logout() }
          catch { logoutError = error.localizedDescription }
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("退出后返回登录页。这台设备上的心愿书、收藏和提交记录会保留。")
    }
    .alert("退出未完成", isPresented: Binding(get: { logoutError != nil }, set: { if !$0 { logoutError = nil } })) {
      Button("知道了", role: .cancel) { logoutError = nil }
    } message: { Text(logoutError ?? "") }
  }
}
