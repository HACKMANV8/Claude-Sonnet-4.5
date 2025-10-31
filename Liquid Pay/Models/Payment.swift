import Foundation

struct Payment: Identifiable, Codable {
    let id: String
    let userId: String
    let billId: String?
    let amountPaise: Int
    let status: String    // success | failed | pending
    let razorpayPaymentId: String?
    let orderId: String?
    let recipient: String?
    let note: String?
    let createdAt: Date?
}


