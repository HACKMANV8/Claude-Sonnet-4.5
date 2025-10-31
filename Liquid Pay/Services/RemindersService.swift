import Foundation
import UserNotifications

final class RemindersService {
    static let shared = RemindersService()
    private let storageKey = "lp_bill_reminders"
    
    func load() -> [BillReminder] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([BillReminder].self, from: data)) ?? []
    }
    
    func save(_ reminders: [BillReminder]) {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func upsert(_ reminder: BillReminder) {
        var all = load()
        if let idx = all.firstIndex(where: { $0.id == reminder.id }) { all[idx] = reminder } else { all.append(reminder) }
        save(all)
        if reminder.enabled { schedule(reminder) } else { cancel(reminder.id) }
    }
    
    func delete(id: String) {
        var all = load()
        all.removeAll { $0.id == id }
        save(all)
        cancel(id)
    }
    
    func schedule(_ reminder: BillReminder) {
        NotificationService.shared.registerBillReminderCategory()
        let content = UNMutableNotificationContent()
        content.title = reminder.isCollect ? "Collect Payment" : "Bill Reminder"
        let amountStr = Currency.formatPaise(reminder.amountPaise)
        content.body = reminder.isCollect ? "Collect \(amountStr) from \(reminder.contactName)" : "Pay \(amountStr) to \(reminder.contactName)"
        content.sound = .default
        content.categoryIdentifier = NotificationService.billReminderCategory
        content.userInfo = [
            "reminderId": reminder.id,
            "contactName": reminder.contactName,
            "upiId": reminder.upiId,
            "amountPaise": reminder.amountPaise,
            "isCollect": reminder.isCollect
        ]
        var date = DateComponents()
        date.weekday = reminder.weekday
        date.hour = reminder.hour
        date.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { err in if let err = err { print("❌ Reminder schedule error: \(err)") } }
    }
    
    func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}


