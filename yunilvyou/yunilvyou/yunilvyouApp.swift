//
//  yunilvyouApp.swift
//  yunilvyou
//
//  Created by mac on 2026/11/18.
//

import SwiftUI

@main
struct yunilvyouApp: App {
  init() {
    TravelTypography.configure()
    if #unavailable(iOS 16) { UIScrollView.appearance().keyboardDismissMode = .interactive }
  }

  var body: some Scene {
    WindowGroup {
      ContentView().font(.travel(.body))
    }
  }
}
