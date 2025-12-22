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
        var payload: [String: Any] = sanitized(attributionStore.attributionData)

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
