//
//  yunilvyouApp.swift
//  yunilvyou
//
//  Created by mac on 2026/11/18.
//

import SwiftUI

@main
struct yunilvyouApp: App {
  @StateObject private var account = TravelAccount()

  init() {
    TravelTypography.configure()
    if #unavailable(iOS 16) { UIScrollView.appearance().keyboardDismissMode = .interactive }
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if account.restoring {
          RestoreLoginPage()
        } else if account.session != nil {
          ContentView()
        } else {
          TravelLoginPage()
        }
      }.environmentObject(account).font(.travel(.body)).tint(Ink.accent)
    }
  }
}
