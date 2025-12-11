import Foundation
import Combine

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
    private let notificationScheduler = NotificationScheduler()
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private let minimumLoadingDuration: TimeInterval = 2
    private let notificationPromptShownKey = "notificationPromptShown"

    var storeId: String? = "id6754849548"
    var pushToken: String?
    var firebaseProjectId: String?

    init(configService: ConfigService = ConfigService(), attributionStore: AttributionDataStore = .shared) {
        self.configService = configService

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

            if shouldShowNotificationPrompt {
                route = .notificationPrompt(url)
            } else {
                route = .web(url)
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
        markNotificationPromptShown()
        if requestPermission {
            notificationScheduler.requestAuthorization()
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

    private var shouldShowNotificationPrompt: Bool {
        UserDefaults.standard.bool(forKey: notificationPromptShownKey) == false
    }

    private func markNotificationPromptShown() {
        UserDefaults.standard.set(true, forKey: notificationPromptShownKey)
    }

    private func handleFailure() {
        if case .web = route {
            return
        }
        route = .native
    }
}
