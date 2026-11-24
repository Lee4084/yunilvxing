import SwiftUI

struct TravelSheetNavigation<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    if #available(iOS 16, *) {
      NavigationStack { content }
    } else {
      NavigationView { content }.navigationViewStyle(.stack)
    }
  }
}

extension View {
  @ViewBuilder func travelSheetSizes() -> some View {
    if #available(iOS 16, *) {
      presentationDetents([.medium, .large])
    } else {
      background(SheetSizeInstaller())
    }
  }

  @ViewBuilder func travelKeyboardDismissal() -> some View {
    if #available(iOS 16, *) {
      scrollDismissesKeyboard(.interactively)
    } else {
      self
    }
  }
}

private struct SheetSizeInstaller: UIViewControllerRepresentable {
  final class Installer: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      var ancestor = parent
      while let controller = ancestor {
        if let sheet = controller.sheetPresentationController {
          sheet.detents = [.medium(), .large()]
          break
        }
        ancestor = controller.parent
      }
    }
  }
  func makeUIViewController(context: Context) -> Installer { Installer() }
  func updateUIViewController(_ controller: Installer, context: Context) {}
}
