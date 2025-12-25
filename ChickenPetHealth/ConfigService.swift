import Foundation

struct ConfigResponse: Decodable {
    let ok: Bool
    let message: String?
    let url: String?
    let expires: TimeInterval?
}

enum ConfigServiceError: Error {
    case endpointNotConfigured
}

final class ConfigService {
    private let endpointString = "https://birrdheallth.com/config.php"
    private let attributionStore: AttributionDataStore
    /// Static payload used when real AppsFlyer data is unavailable (e.g. simulator/testing).
    private let testAttributionPayload: [String: Any] = [
        "af_status": "Non-organic",
        "media_source": "Facebook Ads",
        "campaign": "Test_Campaign",
        "campaign_id": "6068535534218",
        "adset": "s1s3",
        "adset_id": "6073532011618",
        "adgroup": "s1s3",
        "adgroup_id": "6073532011418",
        "is_first_launch": true,
        "is_paid": true,
        "click_time": "2017-07-18 12:55:05",
        "install_time": "2017-07-19 08:06:56.189",
        "af_sub1": "439223",
        "af_sub2": "demo",
        "af_sub3": "demo",
        "af_sub4": "01",
        "af_sub5": "demo",
        "match_type": "probabilistic",
        "deep_link_value": "test_deep_link_value",
        "deep_link_sub1": "test_sub_value",
        "is_deferred": true,
        "timestamp": "2022-12-06T11:47:40.037"
    ]

    init(attributionStore: AttributionDataStore = .shared) {
        self.attributionStore = attributionStore
    }

    func fetchConfig(storeId: String?, pushToken: String?, firebaseProjectId: String?) async throws -> ConfigResponse {
        guard !endpointString.contains("<#") else {
            throw ConfigServiceError.endpointNotConfigured
        }
        guard let endpoint = URL(string: endpointString), endpoint.scheme?.hasPrefix("http") == true else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildRequestBody(storeId: storeId, pushToken: pushToken, firebaseProjectId: firebaseProjectId)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let decoded = try JSONDecoder().decode(ConfigResponse.self, from: data)

        if httpResponse.statusCode != 200 {
            return ConfigResponse(ok: false, message: decoded.message, url: decoded.url, expires: decoded.expires)
        }
        return decoded
    }

    private func buildRequestBody(storeId: String?, pushToken: String?, firebaseProjectId: String?) -> Data? {
        var payload: [String: Any] = sanitized(attributionStore.attributionData)
        if payload.isEmpty {
            payload = testAttributionPayload
        }

        let afId = attributionStore.ensureAppsFlyerId()
        payload["af_id"] = afId

        if let bundleId = Bundle.main.bundleIdentifier {
            payload["bundle_id"] = bundleId
        }

        payload["os"] = "iOS"
        payload["locale"] = Locale.current.identifier

        if let storeId {
            payload["store_id"] = storeId
        }

        let resolvedPush = pushToken ?? "dl28EJCAT4a7UNl86egX-U:APA91bEC1a5aGJL8ZyQHlm-B9togw60MLWP4_zU0ExSXLSa_HiL82Iurj0d-1zJmkMdUcvgCRXTrXtbWQHxmJh49BibLiqZVXPNyrCdZW-_ROTt98f0WCLtt531RYPhWSDOkykcaykE3"
        payload["push_token"] = resolvedPush

        let resolvedFirebase = firebaseProjectId ?? "8934278530"
        payload["firebase_project_id"] = resolvedFirebase

        guard JSONSerialization.isValidJSONObject(payload) else { return nil }
        return try? JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func sanitized(_ dictionary: [String: Any]) -> [String: Any] {
        func unwrapOptional(_ value: Any) -> Any? {
            let mirror = Mirror(reflecting: value)
            guard mirror.displayStyle == .optional else { return value }
            if let child = mirror.children.first {
                return unwrapOptional(child.value)
            }
            return nil
        }

        func sanitizedValue(_ value: Any) -> Any? {
            guard let unwrapped = unwrapOptional(value) else { return nil }

            switch unwrapped {
            case let number as NSNumber:
                return number
            case let string as String:
                return string
            case is NSNull:
                return NSNull()
            case let date as Date:
                return ISO8601DateFormatter().string(from: date)
            case let array as [Any]:
                return array.compactMap { sanitizedValue($0) }
            case let dict as [String: Any]:
                return sanitized(dict)
            default:
                return nil
            }
        }

        var cleaned: [String: Any] = [:]
        dictionary.forEach { key, value in
            guard let sanitized = sanitizedValue(value) else { return }
            cleaned[key] = sanitized
        }
        return cleaned
    }
}
