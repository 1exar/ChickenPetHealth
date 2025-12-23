import Foundation

extension Notification.Name {
    static let remoteNotificationURLReceived = Notification.Name("remoteNotificationURLReceived")
}

/// Stores a one-time URL from a remote notification so the app can open it and then discard it.
final class NotificationLinkStore {
    static let shared = NotificationLinkStore()

    private var pendingURL: URL?
    private let lock = NSLock()

    private init() {}

    @discardableResult
    func store(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let urlString = Self.extractURLString(from: userInfo), let url = URL(string: urlString) else {
            return nil
        }
        store(url: url)
        return url
    }

    func store(url: URL) {
        lock.lock()
        pendingURL = url
        lock.unlock()
    }

    func consume() -> URL? {
        lock.lock()
        let url = pendingURL
        pendingURL = nil
        lock.unlock()
        return url
    }
}

private extension NotificationLinkStore {
    static func extractURLString(from userInfo: [AnyHashable: Any]) -> String? {
        let dataDict = userInfo["data"] as? [AnyHashable: Any]
        let messageDict = userInfo["message"] as? [AnyHashable: Any]
        let candidates: [Any?] = [
            userInfo["url"],
            dataDict?["url"],
            messageDict?["url"],
            (messageDict?["data"] as? [AnyHashable: Any])?["url"],
            userInfo["link"],
            userInfo["deep_link"]
        ]

        for candidate in candidates {
            if let string = candidate as? String, string.isEmpty == false {
                return string
            }
        }

        return nil
    }
}
