import SwiftUI

struct PaymentTestView: View {
    @StateObject private var vm = PaymentViewModel()
    @State private var amountInInr: String = "1"

    var body: some View {
        VStack(spacing: 16) {
            Text("Razorpay Test Payment")
                .font(.headline)

            HStack {
                Text("Amount (INR)")
                TextField("1", text: $amountInInr)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                let rupees = Int(amountInInr) ?? 1
                let paise = max(rupees, 1) * 100
                vm.startPayment(amountPaise: paise)
            } label: {
                Text("Pay with Razorpay")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            if let msg = vm.lastResultMessage {
                Text(msg)
                    .foregroundColor(msg.lowercased().contains("success") ? .green : .red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Payment Test")
    }
}


