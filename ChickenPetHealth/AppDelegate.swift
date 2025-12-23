import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let notificationScheduler = NotificationScheduler()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        notificationScheduler.registerForRemoteNotificationsIfAuthorized()
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

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Messaging.messaging().apnsToken = deviceToken
        PushTokenStore.shared.update(token: tokenString)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Remote notification registration failed: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
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
    func handleRemoteNotificationPayload(_ userInfo: [AnyHashable: Any], shouldNotify: Bool) {
        guard NotificationLinkStore.shared.store(from: userInfo) != nil else { return }
        if shouldNotify {
            NotificationCenter.default.post(name: .remoteNotificationURLReceived, object: nil)
        }
    }
}
