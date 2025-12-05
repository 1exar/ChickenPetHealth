import Foundation
import Combine

/// Stores the latest attribution data gathered from AppsFlyer (or any future provider).
/// These fields stay extremely lightweight so we can ship the gray gate quickly without the SDK.
final class AttributionDataStore: ObservableObject {
    static let shared = AttributionDataStore()

    /// Raw conversion data from AppsFlyer callback.
    @Published private(set) var conversionData: [String: Any] = [:]

    /// Raw unified deep link payload from AppsFlyer.
    @Published private(set) var deepLinkData: [String: Any] = [:]

    /// AppsFlyer installation identifier (af_id).
    @Published private(set) var appsFlyerId: String?

    private init() {}

    func updateConversionData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.conversionData = data
        }
    }

    func updateDeepLinkData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.deepLinkData = data
        }
    }

    func updateAppsFlyerId(_ id: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.appsFlyerId = id
        }
    }
}
