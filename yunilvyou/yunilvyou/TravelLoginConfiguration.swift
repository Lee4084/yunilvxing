import Foundation

enum TravelLoginConfiguration {
  // Each bundle has its own Aliyun scheme. Local provisioning is supplied at build time.
  static let values: [String: String] = {
    guard let id = Bundle.main.bundleIdentifier,
      let url = Bundle.main.url(forResource: "TravelLogin.local", withExtension: "plist"),
      let data = try? Data(contentsOf: url),
      let config = try? PropertyListDecoder().decode([String: [String: String]].self, from: data)
    else { return [:] }
    return config[id] ?? [:]
  }()
}
