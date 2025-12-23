import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var hasDelivered = false

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        guard let imageURL = NotificationService.imageURL(from: request.content.userInfo) else {
            contentHandler(content)
            return
        }

        Task {
            if let attachment = await NotificationService.downloadAttachment(from: imageURL) {
                content.attachments = content.attachments + [attachment]
            }
            deliver(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        guard let content = bestAttemptContent else { return }
        deliver(content)
    }
}

private extension NotificationService {
    static func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
        let possibleKeys = ["image", "imageUrl", "image_url", "mediaUrl", "media_url"]

        func string(for keys: [String], in dict: [AnyHashable: Any]) -> String? {
            for key in keys {
                if let value = dict[key] as? String, value.isEmpty == false {
                    return value
                }
            }
            return nil
        }

        if let topLevel = string(for: possibleKeys, in: userInfo),
           let url = URL(string: topLevel), url.scheme?.hasPrefix("http") == true {
            return url
        }

        if let data = userInfo["data"] as? [AnyHashable: Any],
           let nested = string(for: possibleKeys, in: data),
           let url = URL(string: nested), url.scheme?.hasPrefix("http") == true {
            return url
        }

        return nil
    }

    static func downloadAttachment(from url: URL) async -> UNNotificationAttachment? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard data.isEmpty == false else { return nil }

            let ext = url.pathExtension.isEmpty ? "tmp" : url.pathExtension
            let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            let fileURL = temporaryDirectory.appendingPathComponent("image.\(ext)")
            try data.write(to: fileURL)

            let options: [String: Any]?
            if let mimeType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") {
                options = [UNNotificationAttachmentOptionsTypeHintKey: mimeType]
            } else {
                options = nil
            }

            return try UNNotificationAttachment(identifier: UUID().uuidString, url: fileURL, options: options)
        } catch {
            print("NotificationService attachment error: \(error.localizedDescription)")
            return nil
        }
    }

    func deliver(_ content: UNNotificationContent) {
        guard hasDelivered == false else { return }
        hasDelivered = true
        contentHandler?(content)
    }
}
