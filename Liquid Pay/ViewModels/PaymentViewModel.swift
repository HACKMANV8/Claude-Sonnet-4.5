import Foundation
import Combine
import UIKit
import Razorpay
import FirebaseAuth

@MainActor
final class PaymentViewModel: NSObject, ObservableObject, RazorpayPaymentCompletionProtocolWithData {
    @Published var lastResultMessage: String?
    @Published var showSuccessScreen: Bool = false
    @Published var successPayment: Payment?
    @Published var successPayeeName: String?
    @Published var successCoinsEarned: Int = 0
    
    private var razorpay: RazorpayCheckout?
    private var currentBillId: String?
    private var currentAmountPaise: Int = 0
    private var currentOrderId: String?
    private var currentKeyId: String?
    private var currentPayeeName: String?
    private var firstAttemptAt: Date?

    func startPayment(amountPaise: Int, billId: String, notes: [String: String]? = nil, payeeName: String? = nil) async {
        do {
            // Ensure uid is always in notes for webhook to extract
            guard let uid = Auth.auth().currentUser?.uid else {
                lastResultMessage = "User not authenticated"
                return
            }
            var mergedNotes = notes ?? [:]
            mergedNotes["uid"] = uid
            if let payeeName = payeeName {
                mergedNotes["recipient"] = payeeName
            }
            
            let order = try await CloudFunctionsService.createOrder(amountPaise: amountPaise, billId: billId, notes: mergedNotes)
            let checkout = RazorpayCheckout.initWithKey(order.keyId, andDelegateWithData: self)
            self.razorpay = checkout
            self.currentBillId = billId
            self.currentAmountPaise = amountPaise
            self.currentOrderId = order.orderId
            self.currentKeyId = order.keyId
            self.currentPayeeName = payeeName
            self.firstAttemptAt = Date()

            var options: [String: Any] = [
                "amount": order.amount,
                "currency": order.currency,
                "description": "LiquidPay Payment",
                "theme": ["color": "#4C6EF5"],
                "order_id": order.orderId,
                "notes": ["billId": billId]
            ]
            if let notes = notes {
                var merged = (options["notes"] as? [String: Any]) ?? [:]
                for (k, v) in notes { merged[k] = v }
                options["notes"] = merged
            }

            options["prefill"] = [
                "contact": Auth.auth().currentUser?.phoneNumber ?? "",
                "email": "test@example.com"
            ]

            guard let controller = Self.topMostViewController() else {
                lastResultMessage = "Unable to present Razorpay checkout"
                return
            }

            checkout.open(options, displayController: controller)
        } catch {
            lastResultMessage = "Failed to create order: \(error.localizedDescription)"
        }
    }

    // MARK: - RazorpayPaymentCompletionProtocolWithData
    nonisolated func onPaymentError(_ code: Int32, description str: String, andData data: [AnyHashable : Any]?) {
        DispatchQueue.main.async { [weak self] in
            self?.lastResultMessage = "Payment failed: \(str)"
            Task { try? await self?.record(status: "failed", paymentId: nil) }
        }
    }

    nonisolated func onPaymentSuccess(_ payment_id: String, andData data: [AnyHashable : Any]?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            print("✅ Payment Success Callback - Payment ID: \(payment_id)")
            
            self.lastResultMessage = "Payment success: \(payment_id)"
            
            // Calculate coins earned
            let weekday = Calendar.current.component(.weekday, from: Date())
            let isWeekend = (weekday == 1 || weekday == 7)
            let coins = self.currentAmountPaise * (isWeekend ? 2 : 1)
            
            // Create payment object for success screen
            let payment = Payment(
                id: payment_id,
                userId: Auth.auth().currentUser?.uid ?? "",
                billId: self.currentBillId,
                amountPaise: self.currentAmountPaise,
                status: "success",
                razorpayPaymentId: payment_id,
                orderId: self.currentOrderId,
                recipient: self.currentPayeeName,
                createdAt: Date()
            )
            
            // Set success screen data
            self.successPayment = payment
            self.successPayeeName = self.currentPayeeName
            self.successCoinsEarned = coins
            
            print("✅ Setting showSuccessScreen = true")
            
            // Give Razorpay a moment to dismiss, then show success screen
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            self.showSuccessScreen = true
            
            print("✅ showSuccessScreen is now: \(self.showSuccessScreen)")
            
            // Record payment
            Task { 
                do {
                    try await self.record(status: "success", paymentId: payment_id)
                    print("✅ PaymentViewModel: Successfully recorded payment to Firestore")
                } catch {
                    print("❌ PaymentViewModel: Failed to record payment - \(error.localizedDescription)")
                }
            }
            
            // Optimistically award coins (server webhook also awards idempotently)
            Task {
                guard let uid = Auth.auth().currentUser?.uid else { return }
                try? await RewardsService.shared.awardCoinsForPayment(uid: uid, paymentId: payment_id, amountPaise: self.currentAmountPaise)
                
                // Send notification
                NotificationService.shared.sendPaymentSuccessNotification(amount: self.currentAmountPaise, coinsEarned: coins)
            }
        }
    }

    // MARK: - Helpers
    private static func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
        var controller = window.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }

    // MARK: - Persist
    private func record(status: String, paymentId: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await PaymentsService.shared.recordPayment(userId: uid, billId: currentBillId, amountPaise: currentAmountPaise, status: status, razorpayPaymentId: paymentId, orderId: currentOrderId, recipient: currentPayeeName, firstAttemptAt: firstAttemptAt)
    }
}


