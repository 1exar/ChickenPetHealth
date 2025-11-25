//
//  NotificationScheduler.swift
//  ChickenPetHealth
//

import Foundation
import UserNotifications

final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error.localizedDescription)")
            } else if !granted {
                print("Notification permission denied.")
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
