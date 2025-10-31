import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var points: Int = 0

    private var listener: ListenerRegistration?

    deinit { listener?.remove(); listener = nil }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener?.remove(); listener = nil
        let query = Firestore.firestore()
            .collection("payments")
            .whereField("userId", isEqualTo: uid)
            .whereField("status", isEqualTo: "success")

        listener = query.addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            let totalPaise = docs.reduce(0) { sum, doc in
                sum + (doc.data()["amountPaise"] as? Int ?? 0)
            }
            self?.points = max(0, totalPaise / 100) // 1 point per INR
        }
    }
}

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var points: Int = 0
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

        listener = query.addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self else { return }
            let totalPaise = snapshot?.documents.reduce(0) { partial, doc in
                partial + ((doc.data()["amountPaise"] as? Int) ?? 0)
            } ?? 0
            // Simple rule: 1 point per ₹1 spent
            self.points = totalPaise / 100
            self.isLoading = false
        }
    }

    func stop() { listener?.remove(); listener = nil }
}


