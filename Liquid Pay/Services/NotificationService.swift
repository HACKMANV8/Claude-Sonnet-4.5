import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
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
}

