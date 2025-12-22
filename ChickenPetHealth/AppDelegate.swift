import UIKit
import UserNotifications

#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

/// Minimal AppDelegate to host future AppsFlyer callbacks.
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let notificationScheduler = NotificationScheduler()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        notificationScheduler.registerForRemoteNotificationsIfAuthorized()
        AppsFlyerManager.shared.start(with: launchOptions)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppsFlyerManager.shared.applicationDidBecomeActive()
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return AppsFlyerManager.shared.handleOpen(url: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return AppsFlyerManager.shared.handleUserActivity(userActivity)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushTokenStore.shared.update(token: tokenString)
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().registerUninstall(deviceToken)
        #endif
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Remote notification registration failed: \(error.localizedDescription)")
    }
}

/// Wrapper that becomes a no-op until the AppsFlyer SDK is added to the project.
final class AppsFlyerManager: NSObject {
    static let shared = AppsFlyerManager()
    private var didStart = false
    private let customerUserIdKey = "AppsFlyerManager.customerUserId"

    private override init() {}

    func start(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if canImport(AppsFlyerLib)
        let lib = AppsFlyerLib.shared()

        let devKey = (Bundle.main.object(forInfoDictionaryKey: "AppsFlyerDevKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "fxSHnri96hoMwze37MFpqn"
        let appId = (Bundle.main.object(forInfoDictionaryKey: "AppleAppID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "id6755790499"

        guard
            !devKey.isEmpty, devKey.contains("<#") == false,
            !appId.isEmpty, appId.contains("<#") == false
        else {
            return
        }

        lib.appsFlyerDevKey = devKey
        lib.appleAppID = appId
        #if DEBUG
        lib.isDebug = true
        #else
        lib.isDebug = false
        #endif
        lib.delegate = self
        lib.deepLinkDelegate = self
        lib.customerUserID = resolveCustomerUserId()

        if #available(iOS 14.0, *) {
            lib.waitForATTUserAuthorization(timeoutInterval: 60)
        }

        lib.start()
        didStart = true

        AttributionDataStore.shared.updateAppsFlyerId(lib.getAppsFlyerUID())
        #else
        _ = launchOptions
        #endif
    }

    func applicationDidBecomeActive() {
        #if canImport(AppsFlyerLib)
        guard didStart else { return }
        AppsFlyerLib.shared().start()
        #endif
    }

    func handleOpen(url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleOpen(url, options: options)
        #else
        _ = (url, options)
        #endif
        captureDeepLinkParams(from: url)
        return true
    }

    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        #else
        _ = userActivity
        #endif
        if let url = userActivity.webpageURL {
            captureDeepLinkParams(from: url)
            return true
        }
        return false
    }

    private func captureDeepLinkParams(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              queryItems.isEmpty == false else { return }

        var payload: [String: Any] = [:]
        for item in queryItems {
            guard let name = item.name.removingPercentEncoding, name.isEmpty == false else { continue }
            if let value = item.value?.removingPercentEncoding {
                payload[name] = value
            } else {
                payload[name] = NSNull()
            }
        }

        if payload.isEmpty == false {
            AttributionDataStore.shared.updateDeepLinkData(payload)
        }
    }

    private func resolveCustomerUserId() -> String {
        if let stored = UserDefaults.standard.string(forKey: customerUserIdKey), stored.isEmpty == false {
            return stored
        }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: customerUserIdKey)
        return generated
    }
}

#if canImport(AppsFlyerLib)
extension AppsFlyerManager: AppsFlyerLibDelegate, DeepLinkDelegate {
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
        case .found:
            guard let deepLink = result.deepLink else { return }
            AttributionDataStore.shared.updateDeepLinkData(deepLink.toPayload())
        case .failure, .notFound:
            break
        @unknown default:
            break
        }
    }
}

private extension DeepLink {
    func toPayload() -> [String: Any] {
        var payload: [String: Any] = [:]

        if let clickEvent = value(forKey: "clickEvent") as? [AnyHashable: Any] {
            for (key, value) in clickEvent {
                if let key = key as? String {
                    payload[key] = value
                }
            }
        }

        let mappings: [(key: String, kvc: String)] = [
            ("deep_link_value", "deepLinkValue"),
            ("deep_link_sub1", "deepLinkSub1"),
            ("deep_link_sub2", "deepLinkSub2"),
            ("deep_link_sub3", "deepLinkSub3"),
            ("deep_link_sub4", "deepLinkSub4"),
            ("deep_link_sub5", "deepLinkSub5"),
            ("match_type", "matchType"),
            ("media_source", "mediaSource"),
            ("campaign", "campaign"),
            ("campaign_id", "campaignId"),
            ("af_sub1", "afSub1"),
            ("af_sub2", "afSub2"),
            ("af_sub3", "afSub3"),
            ("af_sub4", "afSub4"),
            ("af_sub5", "afSub5")
        ]

        for mapping in mappings where payload[mapping.key] == nil {
            if let value = value(forKey: mapping.kvc) {
                payload[mapping.key] = value
            }
        }

        if payload["is_deferred"] == nil, let deferred = value(forKey: "isDeferred") {
            payload["is_deferred"] = deferred
        }

        return payload
    }
}

#endif
