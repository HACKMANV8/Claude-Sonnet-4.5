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

    func startPayment(amountPaise: Int, orderId: String? = nil, billId: String? = nil) {
        // Replace with your Razorpay Test Key ID from dashboard
        let keyId = "rzp_test_RZmFoWh9WphMXu"

        let checkout = RazorpayCheckout.initWithKey(keyId, andDelegateWithData: self)
        self.razorpay = checkout
        self.currentBillId = billId
        self.currentAmountPaise = amountPaise

        var options: [String: Any] = [
            "amount": amountPaise,          // paise
            "currency": "INR",
            "description": "LiquidPay Test Payment",
            "theme": ["color": "#4C6EF5"],
            "prefill": [
                "contact": "9999999999",
                "email": "test@example.com"
            ]
        ]

        if let orderId = orderId {
            options["order_id"] = orderId
        }

        guard let controller = Self.topMostViewController() else {
            self.lastResultMessage = "Unable to find top view controller"
            return
        }

        checkout.open(options, displayController: controller)
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
        try? await PaymentsService.shared.recordPayment(userId: uid, billId: currentBillId, amountPaise: currentAmountPaise, status: status, razorpayPaymentId: paymentId)
        if let billId = currentBillId, status == "success" {
            try? await BillsService.shared.updateBillStatus(billId: billId, status: "paid")
        }
    }
}


