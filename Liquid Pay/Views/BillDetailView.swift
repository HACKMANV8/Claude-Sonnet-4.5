import SwiftUI

struct BillDetailView: View {
    let bill: Bill
    @StateObject private var payVM = PaymentViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Bill Details").font(.title2)
            HStack {
                Text("Amount")
                Spacer()
                Text("₹\(bill.amountPaise / 100)").bold()
            }
            HStack {
                Text("Status")
                Spacer()
                Text(bill.status.capitalized)
            }

            Button {
                payVM.startPayment(amountPaise: bill.amountPaise, orderId: nil, billId: bill.id)
            } label: {
                Text("Pay with Razorpay")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if let msg = payVM.lastResultMessage {
                Text(msg).foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Bill")
    }
}


