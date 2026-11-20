import SwiftUI

enum TravelCompatibility {
  // Exercise the iOS 15 navigation and card paths on newer test devices as well.
  static let useLegacyNavigation: Bool = {
    #if DEBUG
    return ProcessInfo.processInfo.arguments.contains("-testIOS15Interaction")
    #else
    return false
    #endif
  }()
}

struct TravelSheetNavigation<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    if #available(iOS 16, *), !TravelCompatibility.useLegacyNavigation {
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
