import Foundation
import Combine
import UIKit
import Razorpay
import FirebaseAuth

@MainActor
final class PaymentViewModel: NSObject, ObservableObject, RazorpayPaymentCompletionProtocolWithData {
    @Published var lastResultMessage: String?
    private var razorpay: RazorpayCheckout?
    private var currentBillId: String?
    private var currentAmountPaise: Int = 0
    private var currentOrderId: String?
    private var currentKeyId: String?

    func startPayment(amountPaise: Int, billId: String) async {
        do {
            let order = try await CloudFunctionsService.createOrder(amountPaise: amountPaise, billId: billId)
            let checkout = RazorpayCheckout.initWithKey(order.keyId, andDelegateWithData: self)
            self.razorpay = checkout
            self.currentBillId = billId
            self.currentAmountPaise = amountPaise
            self.currentOrderId = order.orderId
            self.currentKeyId = order.keyId

            var options: [String: Any] = [
                "amount": order.amount,
                "currency": order.currency,
                "description": "LiquidPay Payment",
                "theme": ["color": "#4C6EF5"],
                "order_id": order.orderId,
                "notes": ["billId": billId]
            ]

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
            Task { await self?.record(status: "failed", paymentId: nil) }
        }
    }

    nonisolated func onPaymentSuccess(_ payment_id: String, andData data: [AnyHashable : Any]?) {
        DispatchQueue.main.async { [weak self] in
            self?.lastResultMessage = "Payment success: \(payment_id)"
            Task { await self?.record(status: "success", paymentId: payment_id) }
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
    private func record(status: String, paymentId: String?) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await PaymentsService.shared.recordPayment(userId: uid, billId: currentBillId, amountPaise: currentAmountPaise, status: status, razorpayPaymentId: paymentId, orderId: currentOrderId)
    }
}


