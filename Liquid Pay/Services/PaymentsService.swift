import Foundation
import FirebaseFirestore

final class PaymentsService {
    static let shared = PaymentsService()
    private let db = Firestore.firestore()

    func recordPayment(userId: String, billId: String?, amountPaise: Int, status: String, razorpayPaymentId: String?) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "billId": billId as Any,
            "amountPaise": amountPaise,
            "status": status,
            "razorpayPaymentId": razorpayPaymentId as Any,
            "createdAt": FieldValue.serverTimestamp()
        ]
        _ = try await db.collection("payments").addDocument(data: data)
    }
}


