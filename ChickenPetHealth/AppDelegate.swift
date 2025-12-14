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

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppsFlyerManager.shared.applicationDidBecomeActive()
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
    private var didStart = false

    private override init() {}

    func start(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if canImport(AppsFlyerLib)
        let lib = AppsFlyerLib.shared()

        let devKey = (Bundle.main.object(forInfoDictionaryKey: "AppsFlyerDevKey") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "fxSHnri96hoMwze37MFpqn"
        let appId = ((Bundle.main.object(forInfoDictionaryKey: "AppleAppID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? "id6755790499"

        guard
            let devKey, !devKey.isEmpty, devKey.contains("<#") == false,
            !appId.isEmpty, appId.contains("<#") == false
        else {
            return
        }

        lib.appsFlyerDevKey = devKey
        lib.appleAppID = appId
        lib.isDebug = false
        lib.delegate = self
        lib.deepLinkDelegate = self

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
        case .found, .success:
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

        if let clickEvent = clickEvent {
            for (key, value) in clickEvent {
                if let key = key as? String {
                    payload[key] = value
                }
            }
        } else {
            for (key, value) in toDictionary() {
                payload[key] = value
            }
        }

        if payload["deep_link_value"] == nil, let value = deepLinkValue {
            payload["deep_link_value"] = value
        }

        if payload["deep_link_sub1"] == nil, let value = deepLinkSub1 {
            payload["deep_link_sub1"] = value
        }

        if payload["deep_link_sub2"] == nil, let value = deepLinkSub2 {
            payload["deep_link_sub2"] = value
        }

        if payload["deep_link_sub3"] == nil, let value = deepLinkSub3 {
            payload["deep_link_sub3"] = value
        }

        if payload["deep_link_sub4"] == nil, let value = deepLinkSub4 {
            payload["deep_link_sub4"] = value
        }

        if payload["deep_link_sub5"] == nil, let value = deepLinkSub5 {
            payload["deep_link_sub5"] = value
        }

        if payload["is_deferred"] == nil {
            payload["is_deferred"] = isDeferred
        }

        return payload
    }
}

#endif
