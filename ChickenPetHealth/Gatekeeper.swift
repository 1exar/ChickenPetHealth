import Foundation
import Combine

@MainActor
final class Gatekeeper: ObservableObject {
    enum Route {
        case loading
        case web(URL)
        case native
    }

    @Published private(set) var route: Route = .loading

    private let configService: ConfigService
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

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

    func refreshConfig() async {
        do {
            let response = try await configService.fetchConfig(storeId: storeId, pushToken: pushToken, firebaseProjectId: firebaseProjectId)

            guard response.ok, let urlString = response.url, let url = URL(string: urlString) else {
                handleFailure()
                return
            }

            route = .web(url)
        } catch let error as ConfigServiceError {
            print("Config not configured: \(error)")
            handleFailure()
        } catch {
            handleFailure()
        }
    }

    private func handleFailure() {
        if case .web = route {
            return
        }
        route = .native
    }
}
