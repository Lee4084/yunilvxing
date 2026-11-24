import SwiftUI
import UIKit

struct GalleryCard: Identifiable, Equatable {
  let id, title, category, summary, image, kind, duration, footer, action: String
  let route: Route
  let isCity: Bool

  init(_ plan: CityPlan) {
    id = plan.id
    title = plan.title
    category = plan.city
    summary = plan.summary
    image = plan.cover + "-cover"
    kind = plan.city
    duration = "\(plan.days)天"
    footer = "行程参考"
    action = "查看图文行程"
    route = .cityPlan(plan)
    isCity = true
  }

  init(_ journey: Journey) {
    id = journey.id
    title = journey.title
    category = journey.category
    summary = journey.summary
    image = journey.image
    kind = journey.kind
    duration = journey.duration
    footer = "费用待沟通"
    action = journey.days == nil ? "查看这段灵感" : "查看行程结构"
    route = .detail(journey)
    isCity = false
  }
}

struct JourneyGallery: View {
  let open: (Route) -> Void
  @State private var cityMode = true
  @State private var query = ""
  @State private var category = "全部"
  @State private var position = GalleryPosition()
  @State private var selection: String?
  @State private var visibleID: String?
  @FocusState private var searching: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var fontSize
  private var items: [GalleryCard] {
    if cityMode { return CityPlans.matches(query, city: category).map { GalleryCard($0) } }
    return Catalog.matches(Catalog.items, query: query, category: category).map { GalleryCard($0) }
  }
  var body: some View {
    let items = self.items
    return TravelPage {
      Cover(
        image: cityMode ? "city" : "photo-417", eyebrow: "CURATED JOURNEY IDEAS", title: "一段行程，\n一幅风景。",
        subtitle: "慢慢滑动，点选想停留的那一程。", height: 190, album: .trips)
      Picker("旅程类型", selection: Binding(get: { cityMode }, set: { newValue in
        cityMode = newValue
        category = "全部"
        query = ""
        selection = nil
        visibleID = nil
        searching = false
      })) {
        Text("城市方案").tag(true)
        Text("灵感示例").tag(false)
      }.pickerStyle(.segmented)
      HStack(alignment: .firstTextBaseline) {
        Text(cityMode ? "城市旅行方案" : "精选旅程").font(.travel(.title))
        Spacer()
        if !cityMode {
          Text("\(items.count) / \(Catalog.items.count)").monospacedDigit()
            .accessibilityLabel("共 \(items.count) 个结果").accessibilityIdentifier("gallery.count")
        }
      }
      HStack {
        Image(systemName: "magnifyingglass")
        TextField("搜索精选旅程", text: $query).focused($searching).submitLabel(.search)
        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44)
          }.accessibilityLabel("清除搜索")
        }
      }.padding(.horizontal, 12).frame(minHeight: 48).background(
        Ink.paper, in: RoundedRectangle(cornerRadius: 14))
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          ForEach(["全部"] + (cityMode ? CityPlans.cities : Catalog.categories), id: \.self) { value in
            Button {
              searching = false
              category = value
            } label: {
              Text(value).font(.travel(.body)).padding(.horizontal, 12).frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(category == value ? Ink.paper : Ink.text)
                .background(category == value ? Ink.text : Ink.paper, in: Capsule())
            }.buttonStyle(.plain).accessibilityAddTraits(category == value ? [.isSelected] : [])
          }
        }
      }
      if items.isEmpty {
        EmptyMessage("没有找到匹配的旅程", systemImage: "magnifyingglass", description: Text("试试其他关键词或主题。"))
        Button("重置搜索与筛选") {
          category = "全部"
          query = ""
        }
      } else {
        GeometryReader { geo in
          GalleryTrack(
            position: position, items: items, selected: selection, reduceMotion: reduceMotion,
            select: { id in
              searching = false
              selection = id
            }, visible: { if !cityMode { visibleID = $0 } }
          )
          .frame(height: trackHeight(geo.size.width))
        }.aspectRatio(fontSize.isAccessibilitySize ? 0.85 : 1.22, contentMode: .fit)
        if !cityMode {
          let current = items.firstIndex { $0.id == visibleID } ?? 0
          HStack(spacing: 6) {
            Spacer()
            ForEach(items) { item in
              Capsule().fill(items[current].id == item.id ? Ink.accent : Ink.line)
                .frame(width: items[current].id == item.id ? 17 : 6, height: 6)
            }
            Spacer()
          }.accessibilityElement(children: .ignore).accessibilityLabel("浏览位置")
            .accessibilityValue("\(current + 1) / \(items.count)")
        }
        if let item = items.first(where: { $0.id == selection }) {
          Panel(item.title) {
            Text(item.summary)
            Text("\(item.kind) · \(item.duration) · \(item.footer)").font(.travel(.footnote))
              .foregroundStyle(
                Ink.muted)
            MainButton(item.action) { open(item.route) }
          }.accessibilityIdentifier("gallery.summary")
        } else {
          Text("点选卡片，查看这段旅程的摘要。").font(.travel(.subheadline))
        }
      }
      Text(cityMode ? "行程参考 · 费用待沟通" : "设计演示 / 灵感示例 · 费用待沟通").font(.travel(.footnote)).foregroundStyle(Ink.muted)
    }.onChange(of: items) { _ in
      if !items.contains(where: { $0.id == selection }) { selection = nil }
    }
  }
  private func trackHeight(_ width: CGFloat) -> CGFloat {
    width / (fontSize.isAccessibilitySize ? 0.85 : 1.22)
  }
}

private final class GalleryPosition {
  var ids: [String] = []
  var fraction: CGFloat = 0
}
private struct GalleryTrack: UIViewRepresentable {
  let position: GalleryPosition
  var items: [GalleryCard], selected: String?, reduceMotion: Bool
  var select: (String) -> Void, visible: (String) -> Void
  func makeUIView(context: Context) -> CardTrack { CardTrack() }
  static func dismantleUIView(_ view: CardTrack, coordinator: ()) {
    view.subviews.compactMap { $0 as? JourneyButton }.forEach { $0.releaseFace() }
  }
  func updateUIView(_ view: CardTrack, context: Context) {
    view.position = position
    view.onSelect = select
    view.onVisible = visible
    view.configure(items, selected: selected, reduceMotion: reduceMotion)
  }
}

private final class JourneyButton: UIButton {
  var move: ((Int) -> Void)?
  var cardFace: UIView?
  var cardController: UIViewController?
  func releaseFace() {
    cardController?.willMove(toParent: nil)
    cardFace?.removeFromSuperview()
    cardController?.removeFromParent()
    cardController = nil
    cardFace = nil
  }
  override var canBecomeFocused: Bool { true }
  override var canBecomeFirstResponder: Bool { true }
  override var keyCommands: [UIKeyCommand]? {
    [
      (UIKeyCommand.inputLeftArrow, #selector(left)),
      (UIKeyCommand.inputRightArrow, #selector(right)),
      ("\r", #selector(activate)), (" ", #selector(activate)),
    ].map {
      let command = UIKeyCommand(input: $0.0, modifierFlags: [], action: $0.1)
      command.wantsPriorityOverSystemBehavior = true
      return command
    }
  }
  @objc func left() { move?(-1) }
  @objc func right() { move?(1) }
  @objc func activate() { sendActions(for: .primaryActionTriggered) }
}

private final class CardTrack: UIScrollView, UIScrollViewDelegate {
  fileprivate var position: GalleryPosition?
  var onSelect: ((String) -> Void)?, onVisible: ((String) -> Void)?
  private var items: [GalleryCard] = [], buttons: [JourneyButton] = []
  private var selected: String?, reduceMotion = false, visible: String?
  private var lastSize = CGSize.zero
  private var loops: Bool { items.count > 1 && items.first?.isCity == true }
  private var strideWidth: CGFloat { bounds.width * 0.82 + 12 }
  private var cycleWidth: CGFloat { CGFloat(items.count) * strideWidth }
  private var adjustingOffset = false
  private var accessibleStart: Int?

  private func item(at slot: Int) -> GalleryCard { items[slot % items.count] }

  override init(frame: CGRect) {
    super.init(frame: frame)
    delegate = self
    showsHorizontalScrollIndicator = false
    bounces = false
    contentInsetAdjustmentBehavior = .never
    // Let the system pan recognizer arbitrate taps and provide deceleration for both input types.
    panGestureRecognizer.allowedTouchTypes = [
      UITouch.TouchType.direct, .indirect, .indirectPointer,
    ].map { NSNumber(value: $0.rawValue) }
    accessibilityIdentifier = "gallery.track"
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func touchesShouldCancel(in view: UIView) -> Bool {
    // A press can start on a card and turn into a drag after the highlight appears.
    if view is JourneyButton { return true }
    return super.touchesShouldCancel(in: view)
  }
  func configure(_ rows: [GalleryCard], selected: String?, reduceMotion: Bool) {
    let changed = rows != items
    self.reduceMotion = reduceMotion
    if changed {
      buttons.forEach { $0.releaseFace(); $0.removeFromSuperview() }
      items = rows
      // Two neighboring copies on either side leave room for flicks across the seam.
      let slots = rows.count * (loops ? 5 : 1)
      buttons = (0..<slots).map { index in
        let item = self.item(at: index)
        let button = JourneyButton()
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.accessibilityLabel = [item.title, item.category, item.duration, item.footer].joined(separator: "，")
        button.accessibilityHint = "选中并居中显示摘要"
        button.accessibilityIdentifier = item.id
        button.addAction(
          UIAction { [weak self] _ in self?.choose(index) }, for: .primaryActionTriggered)
        button.move = { [weak self] direction in
          guard let self else { return }
          let target = min(max(index + direction, 0), self.buttons.count - 1)
          let next = self.buttons[target]
          next.becomeFirstResponder()
          self.scrollRectToVisible(next.frame, animated: !self.reduceMotion)
          UIFocusSystem.focusSystem(for: next)?.requestFocusUpdate(to: next)
        }
        self.addSubview(button)
        return button
      }
      let ids = rows.map(\.id)
      if position?.ids != ids {
        position?.ids = ids
        position?.fraction = 0
      }
      accessibleStart = nil
      lastSize = .zero
      setNeedsLayout()
    }
    self.selected = selected
    for (index, button) in buttons.enumerated() {
      let active = item(at: index).id == selected
      button.accessibilityTraits = active ? [.button, .selected] : .button
      button.layer.borderWidth = active ? 3 : 0
      button.layer.borderColor = UIColor.systemOrange.cgColor
    }
    depth()
  }
  private func displayFace(of item: GalleryCard, in button: JourneyButton) {
    let content = ZStack(alignment: .bottomLeading) {
        Color.black
        GeometryReader { geometry in
          coverImage(item.image).resizable().scaledToFill().frame(
            width: geometry.size.width, height: geometry.size.height
          ).clipped()
        }
        LinearGradient(
          colors: [.clear, .black.opacity(0.25), .black.opacity(0.87)], startPoint: .top,
          endPoint: .bottom)
        VStack(alignment: .leading, spacing: 6) {
          Text(item.category + " · " + item.duration).font(.travel(.caption))
          Text(item.title).font(.travel(.title2))
          Text(item.footer).font(.travel(.footnote))
        }.padding(16).foregroundStyle(.white)
      }
      .overlay(alignment: .topLeading) {
        if !item.isCity {
          Text(item.kind).font(.travel(.caption)).padding(.horizontal, 10).padding(
            .vertical, 5
          )
          .foregroundStyle(Color.black).background(.white.opacity(0.88), in: Capsule()).padding(
            13)
        }
      }
    let face: UIView
    if #available(iOS 16, *) {
      face = UIHostingConfiguration { content }.margins(.all, 0).makeContentView()
    } else {
      let controller = UIHostingController(rootView: content)
      var ancestor: UIResponder? = self
      while let responder = ancestor, !(responder is UIViewController) { ancestor = responder.next }
      guard let parent = ancestor as? UIViewController else { return }
      parent.addChild(controller)
      button.cardController = controller
      face = controller.view
      face.backgroundColor = .clear
    }
    face.isUserInteractionEnabled = false
    face.accessibilityElementsHidden = true
    face.frame = button.bounds
    face.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    button.addSubview(face)
    button.cardFace = face
    if let controller = button.cardController { controller.didMove(toParent: controller.parent) }
  }
  override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.size != lastSize && bounds.width > 0 {
      adjustingOffset = true
      lastSize = bounds.size
      let width = bounds.width * 0.82
      let gap: CGFloat = 12
      let pad = (bounds.width - width) / 2
      for (index, button) in buttons.enumerated() {
        button.bounds = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        button.center = CGPoint(
          x: pad + width / 2 + CGFloat(index) * (width + gap), y: bounds.height / 2)
      }
      let fraction = position?.fraction ?? 0
      contentSize = CGSize(
        width: 2 * pad + CGFloat(buttons.count) * width + CGFloat(max(0, buttons.count - 1)) * gap,
        height: bounds.height)
      let origin = loops ? 2 * cycleWidth : 0
      contentOffset.x = min(max(0, contentSize.width - bounds.width), origin + fraction * strideWidth)
      adjustingOffset = false
    }
    depth()
  }
  private func choose(_ index: Int) {
    guard buttons.indices.contains(index) else { return }
    onSelect?(item(at: index).id)
    setContentOffset(
      CGPoint(x: buttons[index].center.x - bounds.width / 2, y: 0), animated: !reduceMotion)
  }
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard lastSize.width > 0, !adjustingOffset else { return }
    if loops {
      // Move by whole cycles only, keeping the exact drag position between cards.
      if contentOffset.x < cycleWidth || contentOffset.x >= 4 * cycleWidth {
        recenterCycle()
      }
      position?.fraction = logicalOffset / strideWidth
    } else {
      position?.fraction = contentOffset.x / strideWidth
    }
    depth()
  }
  private var logicalOffset: CGFloat {
    let remainder = contentOffset.x.truncatingRemainder(dividingBy: cycleWidth)
    return remainder < 0 ? remainder + cycleWidth : remainder
  }
  private func recenterCycle() {
    guard loops, !adjustingOffset else { return }
    let offset = logicalOffset + 2 * cycleWidth
    guard abs(offset - contentOffset.x) > 0.5 else { return }
    let shift = Int(((offset - contentOffset.x) / strideWidth).rounded())
    let focused = buttons.firstIndex { $0.isFirstResponder || $0.isFocused || $0.accessibilityElementIsFocused() }
    adjustingOffset = true
    contentOffset.x = offset
    adjustingOffset = false
    depth()
    if let focused, buttons.indices.contains(focused + shift) {
      let previous = buttons[focused], next = buttons[focused + shift]
      if previous.isFirstResponder { next.becomeFirstResponder() }
      if previous.isFocused { UIFocusSystem.focusSystem(for: next)?.requestFocusUpdate(to: next) }
      if previous.accessibilityElementIsFocused() { UIAccessibility.post(notification: .layoutChanged, argument: next) }
    }
  }
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { recenterCycle() }
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate { recenterCycle() }
  }
  func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { recenterCycle() }
  private func depth() {
    guard bounds.width > 0, lastSize != .zero, !items.isEmpty, !adjustingOffset else { return }
    let nearest = min(buttons.count - 1, max(0, Int((contentOffset.x / strideWidth).rounded())))
    // Expose each real plan once, using the copy closest to the viewport.
    let start = max(0, min(buttons.count - items.count, nearest - (items.count - 1) / 2))
    if loops && accessibleStart != start {
      let accessible = start..<(start + items.count)
      for (index, button) in buttons.enumerated() {
        button.isAccessibilityElement = accessible.contains(index)
        button.accessibilityIdentifier = button.isAccessibilityElement ? item(at: index).id : nil
      }
      accessibleStart = start
    }
    for (index, button) in buttons.enumerated() {
      // Keep the neighboring cards ready for an inertial swipe without opening the entire album.
      guard abs(button.center.x - bounds.midX) < bounds.width * 2.6 else {
        if button.cardFace != nil { button.releaseFace() }
        continue
      }
      if button.cardFace == nil { displayFace(of: item(at: index), in: button) }
      let delta = min(1, max(-1, (button.center.x - bounds.midX) / bounds.width))
      var transform = CATransform3DIdentity
      if !reduceMotion {
        transform.m34 = -1 / 900
        transform = CATransform3DRotate(transform, -delta * 0.14, 0, 1, 0)
        let scale = 1 - abs(delta) * 0.055
        transform = CATransform3DScale(transform, scale, scale, 1)
      }
      button.layer.transform = transform
    }
    let id = item(at: nearest).id
    if visible != id {
      visible = id
      DispatchQueue.main.async { [weak self] in if self?.visible == id { self?.onVisible?(id) } }
    }
  }
}
