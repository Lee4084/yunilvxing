import SwiftUI
import WebKit

enum TravelAgreement: String, Identifiable, CaseIterable {
  case terms, privacy
  var id: Self { self }
  var title: String { self == .terms ? "用户服务协议" : "隐私政策" }

  var fileURL: URL? {
    Bundle.main.url(forResource: rawValue, withExtension: "html", subdirectory: "Agreements.bundle")
  }
}

struct AgreementLinks: View {
  var documents = TravelAgreement.allCases
  var horizontal = false
  @State private var selected: TravelAgreement?

  var body: some View {
    Group {
      if horizontal {
        HStack(spacing: 10) { links }
      } else {
        VStack(alignment: .leading, spacing: 0) { links }
      }
    }
    .sheet(item: $selected) { document in
      TravelSheetNavigation {
        Group {
          if let file = document.fileURL {
            AgreementReader(file: file)
          } else {
            Text("协议文件暂时无法打开。请联系 94597956@qq.com。")
          }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("完成") { selected = nil } }
      }
    }
  }
  private var links: some View {
    ForEach(documents) { document in
      Button(document.title) { selected = document }
        .frame(minHeight: 44)
    }
  }

}

private struct AgreementReader: UIViewRepresentable {
  let file: URL

  func makeCoordinator() -> Navigation { Navigation() }

  func makeUIView(context: Context) -> WKWebView {
    let settings = WKWebViewConfiguration()
    settings.websiteDataStore = .nonPersistent()
    settings.defaultWebpagePreferences.allowsContentJavaScript = false
    let view = WKWebView(frame: .zero, configuration: settings)
    view.navigationDelegate = context.coordinator
    view.loadFileURL(file, allowingReadAccessTo: file)
    return view
  }

  func updateUIView(_ view: WKWebView, context: Context) {}

  final class Navigation: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
      if url.isFileURL { decisionHandler(.allow); return }
      decisionHandler(.cancel)
      if navigationAction.navigationType == .linkActivated,
        url.scheme == "https" || url.scheme == "mailto" {
        UIApplication.shared.open(url)
      }
    }
  }
}
