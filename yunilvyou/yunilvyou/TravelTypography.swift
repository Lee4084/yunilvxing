import CoreText
import SwiftUI

enum TravelTypography {
  static let face = "YouniSoft-Regular"

  static func configure() {
    guard let url = Bundle.main.url(forResource: face, withExtension: "ttf") else {
      assertionFailure("Missing bundled font: " + face)
      return
    }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    guard let font = UIFont(name: face, size: 18) else {
      assertionFailure("Unable to load " + face)
      return
    }
    let navigation = UINavigationBar.appearance()
    navigation.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: font)]
    navigation.largeTitleTextAttributes = [
      .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: font.withSize(34))
    ]
    let segments = UISegmentedControl.appearance()
    let segmentFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: font.withSize(15))
    for state in [UIControl.State.normal, .selected] {
      UITabBarItem.appearance().setTitleTextAttributes([.font: font.withSize(11)], for: state)
      segments.setTitleTextAttributes([.font: segmentFont], for: state)
    }
  }
}

extension Font {
  static func travel(_ style: Font.TextStyle) -> Font {
    let size: CGFloat
    switch style {
    case .largeTitle: size = 34
    case .title: size = 28
    case .title2: size = 23
    case .title3: size = 21
    case .headline: size = 18
    case .subheadline: size = 16
    case .footnote: size = 14
    case .caption: size = 12
    case .caption2: size = 11
    default: size = 17
    }
    return .custom(TravelTypography.face, size: size, relativeTo: style)
  }
}
