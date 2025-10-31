import Foundation
import FirebaseFirestore

final class PaymentsService {
    static let shared = PaymentsService()
    private let db = Firestore.firestore()

    func recordPayment(userId: String, billId: String?, amountPaise: Int, status: String, razorpayPaymentId: String?, orderId: String?, recipient: String?, firstAttemptAt: Date?) async throws {
        var data: [String: Any] = [
            "userId": userId,
            "billId": billId as Any,
            "amountPaise": amountPaise,
            "status": status,
            "razorpayPaymentId": razorpayPaymentId as Any,
            "orderId": orderId as Any,
            "recipient": recipient as Any,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let firstAttemptAt = firstAttemptAt { data["firstAttemptAt"] = firstAttemptAt }
        
        print("💾 PaymentsService: Recording payment - userId: \(userId), amount: \(amountPaise), status: \(status), paymentId: \(razorpayPaymentId ?? "nil")")
        
        if let paymentId = razorpayPaymentId, !paymentId.isEmpty {
            try await db.collection("payments").document(paymentId).setData(data, merge: true)
            print("✅ PaymentsService: Payment recorded with ID: \(paymentId)")
        } else {
            let ref = try await db.collection("payments").addDocument(data: data)
            print("✅ PaymentsService: Payment recorded with auto ID: \(ref.documentID)")
        }
        if let billId = billId {
            try await BillsService.shared.updateBillStatus(billId: billId, status: status == "success" ? "paid" : status)
        }
    }
}


