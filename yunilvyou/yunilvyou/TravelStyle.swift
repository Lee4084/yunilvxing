import SwiftUI

enum Ink {
  static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(
      uiColor: UIColor { traits in
        let rgb = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
          red: CGFloat(rgb >> 16) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
          blue: CGFloat(rgb & 255) / 255, alpha: 1)
      })
  }
  static let canvas = adaptive(0xFFF7F4, 0x282C3B)
  static let paper = adaptive(0xFFFDFA, 0x343444)
  static let text = adaptive(0x25344A, 0xFEF7F4)
  static let muted = adaptive(0x655F6A, 0xD1C7CE)
  static let accent = adaptive(0xA63E31, 0xFFAA92)
  static let line = adaptive(0xEFD6D1, 0x5B5061)
}

struct TravelPage<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) { content }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
    }.travelKeyboardDismissal().background(Ink.canvas).foregroundStyle(Ink.text)
  }
}

func coverImage(_ name: String) -> Image {
  if name.hasPrefix("photo-"), let photo = CityPlans.photo(name) { return Image(uiImage: photo) }
  return Image(name)
}

enum ScenicAlbum: String {
  case home, design, trips, mine

  var photos: [String] {
    switch self {
    case .mine: return ["mine-xinjiang", "mine-snow", "mine-guilin", "mine-city"]
    case .home: return ["photo-361", "photo-126", "photo-437", "photo-417", "welcome"]
    case .design: return ["photo-264", "photo-326", "photo-353", "photo-160"]
    case .trips: return ["photo-011", "photo-397", "photo-052", "photo-467"]
    }
  }
}

private struct ScenicBackdrop: View {
  let album: ScenicAlbum
  @State private var index = 0

  var body: some View {
    let photos = album.photos
    TabView(selection: $index) {
      ForEach(photos.indices, id: \.self) { page in
        GeometryReader { geo in
          coverImage(photos[page]).resizable().scaledToFill()
            .frame(width: geo.size.width, height: geo.size.height).clipped()
        }.tag(page)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .overlay(alignment: .topTrailing) {
      HStack(spacing: 4) {
        ForEach(photos.indices, id: \.self) { page in
          Capsule().fill(.white.opacity(index == page ? 1 : 0.55))
            .frame(width: index == page ? 14 : 5, height: 5)
        }
      }.padding(7).background(.black.opacity(0.35), in: Capsule()).padding(12)
        .allowsHitTesting(false)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("风景相册").accessibilityValue("第\(index + 1)张，共\(photos.count)张")
    .accessibilityIdentifier("hero." + album.rawValue)
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: index = min(index + 1, photos.count - 1)
      case .decrement: index = max(index - 1, 0)
      @unknown default: break
      }
    }
  }
}

struct Cover: View {
  var image: String, eyebrow: String, title: String, subtitle: String
  var height: CGFloat = 240
  var album: ScenicAlbum? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Spacer(minLength: 22)
      Text(eyebrow).font(.travel(.caption)).tracking(1.4)
      Text(title).font(.travel(.largeTitle)).shadow(color: .black.opacity(0.38), radius: 0.6, y: 1.4)
      Text(subtitle).font(.travel(.subheadline))
    }.padding(22).frame(maxWidth: .infinity, minHeight: height, alignment: .bottomLeading)
      .foregroundStyle(.white)
      .allowsHitTesting(album == nil)
      .background {
        ZStack {
          if let album {
            ScenicBackdrop(album: album)
          } else {
            coverImage(image).resizable().scaledToFill().accessibilityHidden(true)
          }
          LinearGradient(
            colors: [.black.opacity(0.08), .black.opacity(0.12), .black.opacity(0.81)],
            startPoint: .top, endPoint: .bottom).allowsHitTesting(false).accessibilityHidden(true)
        }
      }.clipShape(RoundedRectangle(cornerRadius: 22))
  }
}

struct Panel<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content
  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.travel(.headline)).accessibilityAddTraits(.isHeader)
      content.buttonStyle(PanelActionStyle())
    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
      .background(Ink.paper, in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Ink.line).allowsHitTesting(false))
  }
}

struct MainButton: View {
  @Environment(\.isEnabled) var enabled
  let title: String
  var action: () -> Void
  init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }
  var body: some View {
    Button(title, action: action)
      .buttonStyle(WelcomeButtonStyle(symbol: "arrow.up.right"))
      .opacity(enabled ? 1 : 0.55)
  }
}

struct Choice: View {
  var title: String, selected: Bool, action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        Text(title)
        Spacer()
      }
      .padding(.horizontal, 14).padding(.vertical, 8)
      .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
      .foregroundStyle(selected ? Ink.accent : Ink.text)
      .background(
        selected ? Ink.accent.opacity(0.1) : Ink.canvas, in: RoundedRectangle(cornerRadius: 12)
      )
      .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
  }
}

struct LabeledInput: View {
  var label: String
  @Binding var text: String
  var limit: Int
  var body: some View {
    VStack(alignment: .leading) {
      Text(label).font(.travel(.subheadline))
      if #available(iOS 16, *) {
        TextField(label, text: $text, axis: .vertical).textFieldStyle(.roundedBorder)
      } else {
        TextEditor(text: $text)
          .frame(minHeight: 50, maxHeight: 110).accessibilityLabel(label)
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(Ink.line).allowsHitTesting(false))
      }
      Text(text.optionalValid(limit) ? "\(text.count) / \(limit)" : "请输入有效内容，最多 \(limit) 个字符")
        .font(.travel(.caption)).foregroundStyle(
          text.optionalValid(limit) ? Ink.muted : Ink.accent)
    }
  }
}

struct EmptyMessage: View {
  let title: String, systemImage: String
  var description: Text?
  init(_ title: String, systemImage: String, description: Text? = nil) {
    self.title = title
    self.systemImage = systemImage
    self.description = description
  }
  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: systemImage).font(.travel(.title)).foregroundStyle(Ink.accent)
      Text(title).font(.travel(.headline))
      description?.font(.travel(.subheadline))
    }.multilineTextAlignment(.center).padding(20).frame(maxWidth: .infinity)
  }
}

struct WelcomeButtonStyle: ButtonStyle {
  let symbol: String
  @ScaledMetric(relativeTo: .headline) private var arrowSize: CGFloat = 24
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    let face = RoundedRectangle(cornerRadius: 19, style: .continuous)
    let lift: CGFloat = configuration.isPressed ? 1 : 4
    return configuration.label
      .font(.travel(.headline))
      .multilineTextAlignment(.center)
      .padding(.horizontal, min(arrowSize, 34) + 28)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, minHeight: 55)
      .overlay(alignment: .trailing) {
        Image(systemName: symbol)
          .font(.system(size: min(arrowSize, 34), weight: .semibold, design: .rounded))
          .padding(.trailing, 17).accessibilityHidden(true)
      }
      .foregroundStyle(.white)
      .background {
        ZStack {
          LinearGradient(
            colors: [
              Color(red: 0.86, green: 0.40, blue: 0.30),
              Color(red: 0.70, green: 0.25, blue: 0.23),
              Color(red: 0.61, green: 0.20, blue: 0.25),
            ], startPoint: .top, endPoint: .bottom)
          ForEach([UnitPoint.topLeading, .bottomTrailing], id: \.x) { corner in
            RadialGradient(
              colors: [.white.opacity(0.48), .clear], center: corner,
              startRadius: 1, endRadius: 62)
          }
          face.strokeBorder(
            LinearGradient(
              colors: [.white.opacity(0.76), .white.opacity(0.08), .white.opacity(0.52)],
              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }.clipShape(face)
      }
      .background(face.fill(Color(red: 0.46, green: 0.15, blue: 0.19)).offset(y: lift))
      .shadow(color: .black.opacity(0.16), radius: lift, y: lift)
      .offset(y: 4 - lift)
      .contentShape(face)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
  }
}

struct WelcomeScene: View {
  @ScaledMetric private var side: CGFloat = 20
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("予你旅行").font(.travel(.body))
      Spacer(minLength: 8)
      Text("TRAVEL, MADE PERSONAL").font(.travel(.caption)).tracking(1.5)
      Text("把重要的日子，\n交给一段风景。")
        .font(.travel(.largeTitle))
        .shadow(color: .black.opacity(0.38), radius: 0.6, y: 1.4)
      Text("为自己，也为心里重要的人。").font(.travel(.subheadline))
      Spacer(minLength: 14)
      Text("灵感启程 · 心愿慢慢成形").font(.travel(.footnote))
    }.padding(min(side, 28)).frame(maxWidth: .infinity, minHeight: 278, alignment: .leading)
      .foregroundStyle(.white)
      .allowsHitTesting(false)
      .background {
        ZStack {
          ScenicBackdrop(album: .home)
          LinearGradient(
            colors: [.black.opacity(0.13), .black.opacity(0.32), .black.opacity(0.50)],
            startPoint: .topTrailing, endPoint: .bottomLeading).allowsHitTesting(false).accessibilityHidden(true)
        }
      }.clipShape(RoundedRectangle(cornerRadius: 28))
  }
}

struct PanelActionStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 12).padding(.vertical, 6)
      .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
      .foregroundStyle(configuration.role == .destructive ? Color.red : Ink.accent)
      .background(
        Ink.accent.opacity(configuration.isPressed ? 0.16 : 0.055),
        in: RoundedRectangle(cornerRadius: 12)
      )
      .contentShape(Rectangle()).opacity(enabled ? 1 : 0.5)
  }
}

// Keep the field name visible even when the platform's menu picker hides its label.
struct TravelMenu<Options: View>: View {
  var title: String, value: String
  @ViewBuilder var options: Options
  var body: some View {
    Menu {
      options
    } label: {
      HStack(alignment: .center, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.travel(.footnote)).foregroundStyle(Ink.muted)
          Text(value).font(.travel(.headline)).foregroundStyle(Ink.text)
        }
        Spacer()
        Image(systemName: "chevron.up.chevron.down").foregroundStyle(Ink.accent)
      }.padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(Ink.canvas, in: RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(value)
  }
}
