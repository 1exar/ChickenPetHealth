import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import AppsFlyerLib

final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let notificationScheduler = NotificationScheduler()
    private let attributionStore = AttributionDataStore.shared
    private let appsFlyerDevKey = Bundle.main.object(forInfoDictionaryKey: "AppsFlyerDevKey") as? String
    private let appsFlyerAppId = (Bundle.main.object(forInfoDictionaryKey: "AppleAppID") as? String)?
        .replacingOccurrences(of: "id", with: "")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        notificationScheduler.registerForRemoteNotificationsIfAuthorized()
        configureAppsFlyer(launchOptions: launchOptions)
        Messaging.messaging().token { token, error in
            if let error {
                print("FCM token fetch failed: \(error.localizedDescription)")
            } else if let token, token.isEmpty == false {
                PushTokenStore.shared.update(token: token)
            }
        }
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleRemoteNotificationPayload(remotePayload, shouldNotify: false)
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppsFlyerLib.shared().start()
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Messaging.messaging().apnsToken = deviceToken
        PushTokenStore.shared.update(token: tokenString)
        AppsFlyerLib.shared().registerUninstall(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Remote notification registration failed: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        AppsFlyerLib.shared().handlePushNotification(userInfo)
        handleRemoteNotificationPayload(userInfo, shouldNotify: true)
        completionHandler(.noData)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleRemoteNotificationPayload(response.notification.request.content.userInfo, shouldNotify: true)
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, fcmToken.isEmpty == false else { return }
        PushTokenStore.shared.update(token: fcmToken)
        print("FCM registration token: \(fcmToken)")
    }
}

private extension AppDelegate {
    func configureAppsFlyer(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard let devKey = appsFlyerDevKey, devKey.isEmpty == false else {
            print("AppsFlyer dev key is missing. Set APPSFLYER_DEV_KEY build setting to enable AppsFlyer.")
            return
        }
        guard let appId = appsFlyerAppId, appId.isEmpty == false else {
            print("AppsFlyer app id is missing. Check AppleAppID in Info.plist.")
            return
        }

        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.appsFlyerDevKey = devKey
        appsFlyer.appleAppID = appId
        appsFlyer.delegate = self
        appsFlyer.deepLinkDelegate = self
        appsFlyer.waitForATTUserAuthorization(timeoutInterval: 60)
        appsFlyer.start()
        attributionStore.updateAppsFlyerId(appsFlyer.getAppsFlyerUID())

        // Handle cold-start deep links
        appsFlyer.handlePushNotification(launchOptions?[.remoteNotification] as? [AnyHashable: Any])
    }

    func handleRemoteNotificationPayload(_ userInfo: [AnyHashable: Any], shouldNotify: Bool) {
        guard NotificationLinkStore.shared.store(from: userInfo) != nil else { return }
        if shouldNotify {
            NotificationCenter.default.post(name: .remoteNotificationURLReceived, object: nil)
        }
    }
}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        let normalized = conversionInfo.reduce(into: [String: Any]()) { partialResult, entry in
            guard let key = entry.key as? String else { return }
            partialResult[key] = entry.value
        }
        attributionStore.updateConversionData(normalized)
        attributionStore.updateAppsFlyerId(AppsFlyerLib.shared().getAppsFlyerUID())
    }

    func onConversionDataFail(_ error: Error) {
        print("AppsFlyer conversion data error: \(error.localizedDescription)")
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable : Any]) {
        let normalized = attributionData.reduce(into: [String: Any]()) { partialResult, entry in
            guard let key = entry.key as? String else { return }
            partialResult[key] = entry.value
        }
        attributionStore.updateDeepLinkData(normalized)
    }

    func onAppOpenAttributionFailure(_ error: Error) {
        print("AppsFlyer open attribution error: \(error.localizedDescription)")
    }
}

extension AppDelegate: DeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        switch result.status {
        case .found:
            if let deepLink = result.deepLink?.clickEvent {
                attributionStore.updateDeepLinkData(deepLink)
            }
        case .notFound:
            break
        case .failure:
            break
        @unknown default:
            break
        }
    }
}
