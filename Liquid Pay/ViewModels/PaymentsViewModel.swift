import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PaymentsViewModel: ObservableObject {
    @Published var payments: [Payment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    deinit { listener?.remove(); listener = nil }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener?.remove(); listener = nil
        isLoading = true
        let query = Firestore.firestore()
            .collection("payments")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.errorMessage = error.localizedDescription; self.isLoading = false; return }
            let mapped: [Payment] = snapshot?.documents.compactMap { doc in
                let data = doc.data()
                let ts = data["createdAt"] as? Timestamp
                var noteStr: String? = data["note"] as? String
                if noteStr == nil, let notesDict = data["notes"] as? [String: Any] {
                    let pairs = notesDict.map { "\($0.key): \($0.value)" }.sorted()
                    noteStr = pairs.joined(separator: ", ")
                }
                return Payment(
                    id: doc.documentID,
                    userId: data["userId"] as? String ?? "",
                    billId: data["billId"] as? String,
                    amountPaise: data["amountPaise"] as? Int ?? 0,
                    status: data["status"] as? String ?? "pending",
                    razorpayPaymentId: data["razorpayPaymentId"] as? String,
                    orderId: data["orderId"] as? String,
                    recipient: data["recipient"] as? String,
                    note: noteStr,
                    createdAt: ts?.dateValue()
                )
            } ?? []
            self.payments = mapped
            self.isLoading = false
        }
    }

    func stopListening() {
        listener?.remove(); listener = nil
    }
}


