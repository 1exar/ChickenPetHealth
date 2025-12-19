import Foundation
import Combine
import AppTrackingTransparency
import UserNotifications

@MainActor
final class Gatekeeper: ObservableObject {
    enum Route {
        case loading
        case notificationPrompt(URL)
        case web(URL)
        case native
    }

    @Published private(set) var route: Route = .loading
    @Published var loadingError: Bool = false

    private let configService: ConfigService
    private let attributionStore: AttributionDataStore
    private let notificationScheduler = NotificationScheduler()
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private let minimumLoadingDuration: TimeInterval = 2
    private let notificationPromptCooldownKey = "notificationPromptCooldownUntil"
    private let notificationPromptCooldownInterval: TimeInterval = 3 * 24 * 60 * 60
    private let fallbackAfId = "1688042316289-7152592750959506765"
    private let fallbackPushToken = "dl28EJCAT4a7UNl86egX-U:APA91bEC1a5aGJL8ZyQHlm-B9togw60MLWP4_zU0ExSXLSa_HiL82Iurj0d-1zJmkMdUcvgCRXTrXtbWQHxmJh49BibLiqZVXPNyrCdZW-_ROTt98f0WCLtt531RYPhWSDOkykcaykE3"
    private let fallbackFirebaseProjectId = "8934278530"

    var storeId: String? = "id6755790499"
    var pushToken: String?
    var firebaseProjectId: String?

    init(configService: ConfigService = ConfigService(), attributionStore: AttributionDataStore = .shared) {
        self.configService = configService
        self.attributionStore = attributionStore

        attributionStore.$conversionData
            .combineLatest(attributionStore.$deepLinkData, attributionStore.$appsFlyerId)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                Task { await self?.refreshConfig() }
            }
            .store(in: &cancellables)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await refreshConfig() }
    }

    func restart() {
        loadingError = false
        route = .loading
        Task { await refreshConfig() }
    }

    func refreshConfig() async {
        loadingError = false
        let loadStart = Date()

        do {
            let response = try await configService.fetchConfig(storeId: storeId, pushToken: pushToken, firebaseProjectId: firebaseProjectId)
            await ensureMinimumLoadingDuration(since: loadStart)

            guard response.ok, let urlString = response.url, let url = URL(string: urlString) else {
                handleFailure()
                return
            }

            requestTrackingPermissionIfNeeded()

            let finalURL = appendDeepLinkParams(to: url)
            let notificationStatus = await notificationScheduler.authorizationStatus()
            if shouldShowNotificationPrompt(for: notificationStatus) {
                route = .notificationPrompt(finalURL)
            } else {
                route = .web(finalURL)
            }
        } catch let error as ConfigServiceError {
            print("Config not configured: \(error)")
            await ensureMinimumLoadingDuration(since: loadStart)
            handleFailure()
        } catch {
            await ensureMinimumLoadingDuration(since: loadStart)
            if let urlError = error as? URLError, isConnectivityError(urlError.code) {
                loadingError = true
                return
            }
            handleFailure()
        }
    }

    func openWebAfterNotificationPrompt(url: URL, requestPermission: Bool) {
        if requestPermission {
            notificationScheduler.requestAuthorization { [weak self] granted, status in
                guard let self else { return }
                Task { @MainActor in
                    if granted || self.isAuthorized(status: status) {
                        self.clearNotificationPromptCooldown()
                    } else {
                        self.setNotificationPromptCooldown()
                    }
                }
            }
        } else {
            setNotificationPromptCooldown()
        }
        route = .web(url)
    }

    private func ensureMinimumLoadingDuration(since start: Date) async {
        let elapsed = Date().timeIntervalSince(start)
        let remaining = minimumLoadingDuration - elapsed
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    private func isConnectivityError(_ code: URLError.Code) -> Bool {
        switch code {
        case .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func shouldShowNotificationPrompt(for status: UNAuthorizationStatus) -> Bool {
        if isAuthorized(status: status) { return false }

        if let cooldownDate = nextNotificationPromptDate, Date() < cooldownDate {
            return false
        }

        return true
    }

    private func setNotificationPromptCooldown() {
        let nextDate = Date().addingTimeInterval(notificationPromptCooldownInterval)
        UserDefaults.standard.set(nextDate.timeIntervalSince1970, forKey: notificationPromptCooldownKey)
    }

    private func clearNotificationPromptCooldown() {
        UserDefaults.standard.removeObject(forKey: notificationPromptCooldownKey)
    }

    private var nextNotificationPromptDate: Date? {
        let timestamp = UserDefaults.standard.double(forKey: notificationPromptCooldownKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func handleFailure() {
        if case .web = route {
            return
        }
        requestNotificationPermissionForNativeFallback()
        route = .native
    }

    private func requestTrackingPermissionIfNeeded() {
        guard #available(iOS 14, *) else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { _ in }
    }

    private func requestNotificationPermissionForNativeFallback() {
        // When no web link is available we stay in the native app, so request notifications immediately.
        notificationScheduler.requestAuthorization()
    }

    private func isAuthorized(status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func appendDeepLinkParams(to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        let attribution = attributionStore.attributionData

        func hasItem(named name: String) -> Bool {
            items.contains { $0.name == name }
        }

        func addItem(name: String, value: Any) {
            guard hasItem(named: name) == false else { return }
            switch value {
            case let string as String where string.isEmpty == false:
                items.append(URLQueryItem(name: name, value: string))
            case let number as NSNumber:
                items.append(URLQueryItem(name: name, value: number.stringValue))
            default:
                break
            }
        }

        func firstValue(for keys: [String]) -> Any? {
            for key in keys {
                if let value = attribution[key] {
                    switch value {
                    case let string as String where string.isEmpty == false:
                        return string
                    case let number as NSNumber:
                        return number
                    default:
                        continue
                    }
                }
            }
            return nil
        }

        // sub_id mapping (AppsFlyer af_sub*)
        let subIdMappings: [(name: String, keys: [String])] = [
            ("sub_id_1", ["sub_id_1", "af_sub1"]),
            ("sub_id_2", ["sub_id_2", "af_sub2"]),
            ("sub_id_3", ["sub_id_3", "af_sub3"]),
            ("sub_id_4", ["sub_id_4", "af_sub4"]),
            ("sub_id_5", ["sub_id_5", "af_sub5"])
        ]

        for mapping in subIdMappings {
            if let value = firstValue(for: mapping.keys) {
                addItem(name: mapping.name, value: value)
            }
        }

        // Fallback for sub_id_5: store id if still missing.
        if hasItem(named: "sub_id_5") == false, let storeId {
            addItem(name: "sub_id_5", value: storeId)
        }

        // deep link fields
        if let value = firstValue(for: ["deep_link_value"]) {
            addItem(name: "deep_link_value", value: value)
        }

        if hasItem(named: "deep_link_sub1") == false {
            let subs: [Any?] = [
                firstValue(for: ["deep_link_sub1"]),
                firstValue(for: ["deep_link_sub2"]),
                firstValue(for: ["deep_link_sub3"]),
                firstValue(for: ["deep_link_sub4"]),
                firstValue(for: ["deep_link_sub5"])
            ]
            if let firstSub = subs.compactMap({ $0 }).first {
                addItem(name: "deep_link_sub1", value: firstSub)
            }
        }

        // extra_param_7 bundle (af_id & campaign info)
        if hasItem(named: "extra_param_7") == false {
            let afId = firstValue(for: ["af_id"]) ?? attributionStore.appsFlyerId ?? fallbackAfId
            let agency = firstValue(for: ["agency"])
            let campaign = firstValue(for: ["campaign"])
            let campaignId = firstValue(for: ["campaign_id"])
            let mediaSource = firstValue(for: ["media_source"])

            let parts: [(String, Any?)] = [
                ("af_id", afId),
                ("agency", agency),
                ("campaign", campaign),
                ("campaign_id", campaignId),
                ("media_source", mediaSource)
            ]

            let filled = parts.compactMap { key, value -> String? in
                guard let value else { return nil }
                let stringValue: String
                switch value {
                case let str as String: stringValue = str
                case let number as NSNumber: stringValue = number.stringValue
                default: return nil
                }
                return "\(key)=\(stringValue)"
            }

            if filled.isEmpty == false {
                let composed = filled.joined(separator: "&")
                addItem(name: "extra_param_7", value: composed)
            }
        }

        // Fallback: pass through all string/number attribution params as query if missing.
        for (key, value) in attribution {
            addItem(name: key, value: value)
        }

        // Client-side extra params to mirror request body for tester pages.
        let resolvedAfId = attributionStore.appsFlyerId ?? fallbackAfId
        addItem(name: "af_id", value: resolvedAfId)
        if let bundleId = Bundle.main.bundleIdentifier {
            addItem(name: "bundle_id", value: bundleId)
        }
        addItem(name: "os", value: "iOS")
        let resolvedLocale = Locale.current.identifier.isEmpty ? "En" : Locale.current.identifier
        addItem(name: "locale", value: resolvedLocale)
        if let storeId {
            addItem(name: "store_id", value: storeId)
        }
        addItem(name: "push_token", value: pushToken ?? fallbackPushToken)
        addItem(name: "firebase_project_id", value: firebaseProjectId ?? fallbackFirebaseProjectId)

        guard items.isEmpty == false else { return url }
        components.queryItems = items
        return components.url ?? url
    }
}
