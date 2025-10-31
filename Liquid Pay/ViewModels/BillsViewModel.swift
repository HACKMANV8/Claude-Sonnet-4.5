import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class BillsViewModel: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    deinit { listener?.remove(); listener = nil }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        stopListening()
        isLoading = true
        let query = Firestore.firestore()
            .collection("bills")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.errorMessage = error.localizedDescription; self.isLoading = false; return }
            let mapped: [Bill] = snapshot?.documents.compactMap { doc in
                let data = doc.data()
                let ts = data["createdAt"] as? Timestamp
                return Bill(
                    id: doc.documentID,
                    userId: data["userId"] as? String ?? "",
                    amountPaise: data["amountPaise"] as? Int ?? 0,
                    status: data["status"] as? String ?? "pending",
                    createdAt: ts?.dateValue()
                )
            } ?? []
            self.bills = mapped
            self.isLoading = false
        }
    }

    func stopListening() {
        listener?.remove(); listener = nil
    }

    func createBill(amountInRupees: Int) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        errorMessage = nil
        do {
            let paise = max(1, amountInRupees) * 100
            _ = try await BillsService.shared.createBill(userId: uid, amountPaise: paise)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


