import Foundation
import FirebaseFirestore

final class BillsService {
    static let shared = BillsService()
    private let db = Firestore.firestore()

    func createBill(userId: String, amountPaise: Int) async throws -> String {
        let data: [String: Any] = [
            "userId": userId,
            "amountPaise": amountPaise,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]
        let ref = try await db.collection("bills").addDocument(data: data)
        return ref.documentID
    }

    func updateBillStatus(billId: String, status: String) async throws {
        try await db.collection("bills").document(billId).updateData(["status": status])
    }
}


