import Foundation

struct BillReminder: Identifiable, Codable, Equatable {
    let id: String
    var contactName: String
    var upiId: String
    var amountPaise: Int
    var isCollect: Bool
    // Weekday: 1 = Sunday ... 7 = Saturday, matches Calendar.component(.weekday)
    var weekday: Int
    var hour: Int
    var minute: Int
    var enabled: Bool
    
    init(id: String = UUID().uuidString,
         contactName: String,
         upiId: String,
         amountPaise: Int,
         isCollect: Bool,
         weekday: Int,
         hour: Int,
         minute: Int,
         enabled: Bool = true) {
        self.id = id
        self.contactName = contactName
        self.upiId = upiId
        self.amountPaise = amountPaise
        self.isCollect = isCollect
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.enabled = enabled
    }
}


