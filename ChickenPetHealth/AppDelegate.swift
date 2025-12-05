import UIKit

#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

/// Minimal AppDelegate to host future AppsFlyer callbacks.
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppsFlyerManager.shared.start(with: launchOptions)
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return AppsFlyerManager.shared.handleOpen(url: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return AppsFlyerManager.shared.handleUserActivity(userActivity)
    }
}

/// Wrapper that becomes a no-op until the AppsFlyer SDK is added to the project.
final class AppsFlyerManager: NSObject {
    static let shared = AppsFlyerManager()
    private override init() {}

    func start(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // Will be filled once dev key, app id and SDK are available.
    }

    func handleOpen(url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return false
    }

    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        return false
    }
}

#if canImport(AppsFlyerLib)
extension AppsFlyerManager: AppsFlyerLibDelegate, DeepLinkDelegate {
    func start(with launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        let lib = AppsFlyerLib.shared()
        lib.appsFlyerDevKey = "<#DEV_KEY#>"
        lib.appleAppID = "6754849548"
        lib.isDebug = false
        lib.delegate = self
        lib.deepLinkDelegate = self
        lib.start()

        if let afId = lib.getAppsFlyerUID() {
            AttributionDataStore.shared.updateAppsFlyerId(afId)
        }
    }

    func handleOpen(url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
    }

    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    // MARK: - Attribution callbacks

    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        if let dict = conversionInfo as? [String: Any] {
            AttributionDataStore.shared.updateConversionData(dict)
        }
    }

    func onConversionDataFail(_ error: Error) {
        print("AppsFlyer conversion data failed: \(error.localizedDescription)")
    }

    func onDeepLinking(_ result: DeepLinkResult) {
        switch result.status {
        case .found, .success:
            if let data = result.deepLink?.toJSON() {
                AttributionDataStore.shared.updateDeepLinkData(data)
            }
        case .failure, .notFound:
            break
        @unknown default:
            break
        }
    }
}

private extension DeepLink {
    func toJSON() -> [String: Any] {
        var payload: [String: Any] = [:]
        for (key, value) in toDictionary() {
            payload[key] = value
        }
        return payload
    }
}

#endif
