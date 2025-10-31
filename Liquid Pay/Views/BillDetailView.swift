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
                Text(Currency.formatPaise(bill.amountPaise)).bold()
            }
            HStack {
                Text("Status")
                Spacer()
                Text(bill.status.capitalized)
            }

            Button {
                Task { await payVM.startPayment(amountPaise: bill.amountPaise, billId: bill.id) }
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


