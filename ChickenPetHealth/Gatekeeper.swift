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
    private let pushTokenStore: PushTokenStore
    private let notificationLinkStore = NotificationLinkStore.shared
    private let notificationScheduler = NotificationScheduler()
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private var isUsingNotificationURL = false
    private let minimumLoadingDuration: TimeInterval = 2
    private let notificationPromptCooldownKey = "notificationPromptCooldownUntil"
    private let notificationPromptCooldownInterval: TimeInterval = 3 * 24 * 60 * 60
    private let fallbackPushToken = "dl28EJCAT4a7UNl86egX-U:APA91bEC1a5aGJL8ZyQHlm-B9togw60MLWP4_zU0ExSXLSa_HiL82Iurj0d-1zJmkMdUcvgCRXTrXtbWQHxmJh49BibLiqZVXPNyrCdZW-_ROTt98f0WCLtt531RYPhWSDOkykcaykE3"
    private let fallbackFirebaseProjectId = "8934278530"

    var storeId: String? = "id6755790499"
    var pushToken: String?
    var firebaseProjectId: String?

    init(
        configService: ConfigService = ConfigService(),
        pushTokenStore: PushTokenStore = .shared
    ) {
        self.configService = configService
        self.pushTokenStore = pushTokenStore
        self.pushToken = pushTokenStore.token

        pushTokenStore.$token
            .removeDuplicates()
            .sink { [weak self] token in
                guard let self else { return }
                self.pushToken = token
                Task { await self.refreshConfig() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .remoteNotificationURLReceived)
            .sink { [weak self] _ in
                self?.openPendingNotificationURLIfNeeded()
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
        isUsingNotificationURL = false
        Task { await refreshConfig() }
    }

    func refreshConfig() async {
        loadingError = false
        let loadStart = Date()

        if isUsingNotificationURL {
            return
        }

        if openPendingNotificationURLIfNeeded() {
            return
        }

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
                    self.route = .web(url)
                }
            }
        } else {
            setNotificationPromptCooldown()
            route = .web(url)
        }
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

    @discardableResult
    private func openPendingNotificationURLIfNeeded() -> Bool {
        guard let notificationURL = notificationLinkStore.consume() else { return false }
        route = .web(notificationURL)
        isUsingNotificationURL = true
        return true
    }
}
