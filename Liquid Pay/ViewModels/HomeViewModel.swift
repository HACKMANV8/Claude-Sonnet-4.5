import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var totalPaidPaise: Int = 0
    @Published var lastPaymentDate: Date?
    @Published var thisMonthPaidPaise: Int = 0
    @Published var lastPaymentAmountPaise: Int?
    @Published var lastPaymentStatus: String?
    @Published var last7DaysPaise: [Int] = [] // 7 values, oldest -> newest
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

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ HomeViewModel: Error fetching payments - \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            
            let payments: [Payment] = snapshot?.documents.compactMap { doc in
                let data = doc.data()
                let ts = data["createdAt"] as? Timestamp
                return Payment(
                    id: doc.documentID,
                    userId: data["userId"] as? String ?? "",
                    billId: data["billId"] as? String,
                    amountPaise: data["amountPaise"] as? Int ?? 0,
                    status: data["status"] as? String ?? "pending",
                    razorpayPaymentId: data["razorpayPaymentId"] as? String,
                    orderId: data["orderId"] as? String,
                    recipient: data["recipient"] as? String,
                    createdAt: ts?.dateValue()
                )
            } ?? []

            print("📊 HomeViewModel: Fetched \(payments.count) total payments")
            let successPayments = payments.filter { $0.status == "success" }
            print("✅ HomeViewModel: Found \(successPayments.count) successful payments")
            
            self.totalPaidPaise = successPayments.reduce(0) { $0 + $1.amountPaise }
            let latest = successPayments.first
            self.lastPaymentDate = latest?.createdAt
            self.lastPaymentAmountPaise = latest?.amountPaise
            self.lastPaymentStatus = latest?.status
            self.thisMonthPaidPaise = Self.computeThisMonthPaidPaise(payments: successPayments)
            self.last7DaysPaise = Self.computeLast7DaysSeries(payments: successPayments)
            
            print("💰 HomeViewModel: Total spent = \(self.totalPaidPaise) paise")
            print("📅 HomeViewModel: Last payment date = \(self.lastPaymentDate?.description ?? "none")")
            print("🗓️ HomeViewModel: This month spent = \(self.thisMonthPaidPaise) paise")
            print("📈 HomeViewModel: 7-day series = \(self.last7DaysPaise)")
            
            self.isLoading = false
        }
    }

    private static func computeThisMonthPaidPaise(payments: [Payment]) -> Int {
        guard let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) else {
            return 0
        }
        return payments
            .filter { ($0.createdAt ?? .distantPast) >= startOfMonth }
            .reduce(0) { $0 + $1.amountPaise }
    }

    private static func computeLast7DaysSeries(payments: [Payment]) -> [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Oldest -> newest across 7 days
        let days: [Date] = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        var bucket: [Date: Int] = [:]
        for day in days { bucket[day] = 0 }

        for p in payments {
            guard let created = p.createdAt else { continue }
            let key = calendar.startOfDay(for: created)
            if bucket[key] != nil {
                bucket[key, default: 0] += p.amountPaise
            }
        }

        return days.map { bucket[$0] ?? 0 }
    }
}

