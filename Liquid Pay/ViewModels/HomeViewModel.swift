import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var totalPaidPaise: Int = 0
    @Published var recentPayments: [Payment] = []
    @Published var isLoading: Bool = false

    private var listener: ListenerRegistration?

    deinit { listener?.remove(); listener = nil }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        listener?.remove(); listener = nil
        let query = Firestore.firestore()
            .collection("payments")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 10)

        listener = query.addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self else { return }
            let mapped: [Payment] = snapshot?.documents.compactMap { doc in
                let data = doc.data()
                let ts = data["createdAt"] as? Timestamp
                return Payment(
                    id: doc.documentID,
                    userId: data["userId"] as? String ?? "",
                    billId: data["billId"] as? String,
                    amountPaise: data["amountPaise"] as? Int ?? 0,
                    status: data["status"] as? String ?? "pending",
                    razorpayPaymentId: data["razorpayPaymentId"] as? String,
                    createdAt: ts?.dateValue()
                )
            } ?? []
            self.recentPayments = mapped
            self.totalPaidPaise = mapped.filter { $0.status == "success" }.reduce(0) { $0 + $1.amountPaise }
            self.isLoading = false
        }
    }
}

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var totalSpentPaise: Int = 0
    @Published var lastPaymentDate: Date?
    @Published var isLoading: Bool = false

    private var listener: ListenerRegistration?

    deinit { listener?.remove(); listener = nil }

    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        listener?.remove(); listener = nil
        let query = Firestore.firestore()
            .collection("payments")
            .whereField("userId", isEqualTo: uid)
            .whereField("status", isEqualTo: "success")
            .order(by: "createdAt", descending: true)

        listener = query.addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self else { return }
            let docs = snapshot?.documents ?? []
            self.totalSpentPaise = docs.reduce(0) { $0 + ( ($1.data()["amountPaise"] as? Int) ?? 0 ) }
            self.lastPaymentDate = (docs.first? .data()["createdAt"] as? Timestamp)?.dateValue()
            self.isLoading = false
        }
    }

    func stop() { listener?.remove(); listener = nil }
}


