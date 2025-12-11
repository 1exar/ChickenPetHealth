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
        var payload: [String: Any] = sanitized(attributionStore.conversionData)

        for (key, value) in sanitized(attributionStore.deepLinkData) where payload[key] == nil {
            payload[key] = value
        }

        if let afId = attributionStore.appsFlyerId {
            payload["af_id"] = afId
        }

        if let bundleId = Bundle.main.bundleIdentifier {
            payload["bundle_id"] = bundleId
        }

        payload["os"] = "iOS"
        payload["locale"] = Locale.current.identifier

        if let storeId {
            payload["store_id"] = storeId
        }

        if let pushToken {
            payload["push_token"] = pushToken
        }

        if let firebaseProjectId {
            payload["firebase_project_id"] = firebaseProjectId
        }

        guard JSONSerialization.isValidJSONObject(payload) else { return nil }
        return try? JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func sanitized(_ dictionary: [String: Any]) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        dictionary.forEach { key, value in
            switch value {
            case let number as NSNumber:
                cleaned[key] = number
            case let string as String:
                cleaned[key] = string
            case let date as Date:
                cleaned[key] = ISO8601DateFormatter().string(from: date)
            case let array as [Any]:
                let sanitizedArray: [Any] = array.compactMap { element in
                    if let string = element as? String { return string }
                    if let number = element as? NSNumber { return number }
                    return nil
                }
                cleaned[key] = sanitizedArray
            case let dict as [String: Any]:
                cleaned[key] = sanitized(dict)
            default:
                break
            }
        }
        return cleaned
    }
}
