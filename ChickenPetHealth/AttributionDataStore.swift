import Foundation
import Combine

/// Stores the latest attribution data gathered from AppsFlyer (or any future provider).
/// These fields stay extremely lightweight so we can ship the gray gate quickly without the SDK.
final class AttributionDataStore: ObservableObject {
    static let shared = AttributionDataStore()
    private let appsFlyerIdKey = "AttributionDataStore.appsFlyerId"

    /// Raw conversion data from AppsFlyer callback.
    @Published private(set) var conversionData: [String: Any] = [:]

    /// Raw unified deep link payload from AppsFlyer.
    @Published private(set) var deepLinkData: [String: Any] = [:]

    /// Merged attribution payload for outgoing requests.
    /// If a key is present in multiple sources, the first received value wins.
    @Published private(set) var attributionData: [String: Any] = [:]

    /// AppsFlyer installation identifier (af_id).
    @Published private(set) var appsFlyerId: String?

    private init() {
        appsFlyerId = UserDefaults.standard.string(forKey: appsFlyerIdKey)
    }

    func updateConversionData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.conversionData = data
            self?.mergeFirstReceived(from: data)
        }
    }

    func updateDeepLinkData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.deepLinkData = data
            self?.mergeFirstReceived(from: data)
        }
    }

    func updateAppsFlyerId(_ id: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.appsFlyerId = id
            if let id, id.isEmpty == false {
                UserDefaults.standard.set(id, forKey: self?.appsFlyerIdKey ?? "")
            }
        }
    }

    /// Returns an existing AF id or generates a unique, persisted fallback to keep notification flows working when the SDK is absent.
    func ensureAppsFlyerId() -> String {
        if let current = appsFlyerId, current.isEmpty == false {
            return current
        }

        if let stored = UserDefaults.standard.string(forKey: appsFlyerIdKey), stored.isEmpty == false {
            appsFlyerId = stored
            return stored
        }

        let generated = "af-\(UUID().uuidString.lowercased())"
        updateAppsFlyerId(generated)
        return generated
    }

    private func mergeFirstReceived(from data: [String: Any]) {
        var merged = attributionData
        for (key, value) in data where merged[key] == nil {
            merged[key] = value
        }
        attributionData = merged
    }
}
