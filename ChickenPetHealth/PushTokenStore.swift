import Foundation
import Combine

/// Persists and publishes the current APNs token so we can attach it to requests.
final class PushTokenStore: ObservableObject {
    static let shared = PushTokenStore()

    @Published private(set) var token: String?

    private let defaultsKey = "PushTokenStore.token"

    private init() {
        token = UserDefaults.standard.string(forKey: defaultsKey)
    }

    func update(token: String?) {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.token = trimmed
            if let trimmed, trimmed.isEmpty == false {
                UserDefaults.standard.set(trimmed, forKey: self.defaultsKey)
            }
        }
    }
}
