import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    static let billReminderCategory = "BILL_REMINDER"
    static let payAction = "PAY_NOW"
    static let collectAction = "COLLECT_NOW"
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }
    
    func sendPaymentSuccessNotification(amount: Int, coinsEarned: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Payment Successful! 🎉"
        content.body = "You paid \(Currency.formatPaise(amount)) and earned \(coinsEarned) Liquid Coins!"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            }
        }
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    func registerBillReminderCategory() {
        let pay = UNNotificationAction(identifier: Self.payAction, title: "Pay Now", options: [.foreground])
        let collect = UNNotificationAction(identifier: Self.collectAction, title: "Collect", options: [.foreground])
        let cat = UNNotificationCategory(identifier: Self.billReminderCategory, actions: [pay, collect], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }
}

