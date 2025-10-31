import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

final class UserPCIViewModel: ObservableObject {
    @Published var score: Int = 650
    @Published var streakDays: Int = 0
    @Published var trend: [PCITrendPoint] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { self.isLoading = false; return }
        stop()
        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err { self.errorMessage = err.localizedDescription; self.isLoading = false; return }
            guard let data = snap?.data() else { 
                // Initialize with default if no data exists
                Task { await self.initializeDefaultPCI(uid: uid) }
                self.isLoading = false
                return 
            }
            let s = data["pciScore"] as? Int ?? (data["pciScore"] as? Double).map { Int($0) } ?? 650
            self.score = s
            self.streakDays = data["pciStreakDays"] as? Int ?? 0
            if let arr = data["pciTrend"] as? [[String: Any]] {
                self.trend = arr.compactMap { item in
                    guard let ts = item["ts"] as? Timestamp else { return nil }
                    let sc = (item["score"] as? Int) ?? Int((item["score"] as? Double) ?? 0)
                    return PCITrendPoint(date: ts.dateValue(), score: sc)
                }.sorted { $0.date < $1.date }
            }
            self.isLoading = false
        }
    }
    
    private func initializeDefaultPCI(uid: String) async {
        let initialData: [String: Any] = [
            "pciScore": 650,
            "pciStreakDays": 0,
            "pciTrend": [["ts": Timestamp(date: Date()), "score": 650]],
            "pciUpdatedAt": Timestamp(date: Date()),
            "pciLastPaymentDate": Timestamp(date: Date()),
            "pciDecayAnchor": Timestamp(date: Date())
        ]
        try? await db.collection("users").document(uid).setData(initialData, merge: true)
    }
    
    func stop() { listener?.remove(); listener = nil }
}

struct PCITrendPoint: Identifiable { let id = UUID(); let date: Date; let score: Int }


