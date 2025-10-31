import Foundation
import FirebaseFirestore

final class PaymentsService {
    static let shared = PaymentsService()
    private let db = Firestore.firestore()

    func recordPayment(userId: String, billId: String?, amountPaise: Int, status: String, razorpayPaymentId: String?, orderId: String?) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "billId": billId as Any,
            "amountPaise": amountPaise,
            "status": status,
            "razorpayPaymentId": razorpayPaymentId as Any,
            "orderId": orderId as Any,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let paymentId = razorpayPaymentId, !paymentId.isEmpty {
            try await db.collection("payments").document(paymentId).setData(data, merge: true)
        } else {
            _ = try await db.collection("payments").addDocument(data: data)
        }
        if let billId = billId {
            try await BillsService.shared.updateBillStatus(billId: billId, status: status == "success" ? "paid" : status)
        }
    }
}


