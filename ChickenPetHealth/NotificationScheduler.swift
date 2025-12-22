//
//  NotificationScheduler.swift
//  ChickenPetHealth
//

import Foundation
import UserNotifications
import UIKit

final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(completion: ((Bool, UNAuthorizationStatus) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            self.center.getNotificationSettings { settings in
                if granted || self.isAuthorized(status: settings.authorizationStatus) {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                completion?(granted, settings.authorizationStatus)
            }

            if let error {
                print("Notification permission error: \(error.localizedDescription)")
            } else if !granted {
                print("Notification permission denied.")
            }
        }
    }

    func registerForRemoteNotificationsIfAuthorized() {
        center.getNotificationSettings { settings in
            guard self.isAuthorized(status: settings.authorizationStatus) else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func schedule(reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if reminder.details.isEmpty == false {
            content.body = reminder.details
        }
        content.sound = UNNotificationSound.default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    func cancel(reminderID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID.uuidString])
    }
}

private extension NotificationScheduler {
    func isAuthorized(status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}
