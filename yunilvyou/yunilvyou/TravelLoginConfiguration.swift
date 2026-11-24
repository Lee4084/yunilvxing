import Foundation

enum TravelLoginConfiguration {
  static let appKey = "yuni-ios-travel"
  static let apiBaseURL = URL(string: "https://yunilvyou.80782.com/api/v1/")

  static let values: [String: String] = {
    guard let id = Bundle.main.bundleIdentifier,
      let url = Bundle.main.url(forResource: "TravelLogin.local", withExtension: "plist"),
      let data = try? Data(contentsOf: url),
      let config = try? PropertyListDecoder().decode([String: [String: String]].self, from: data)
    else { return [:] }
    return config[id] ?? [:]
  }()
}
