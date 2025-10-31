import SwiftUI
import FirebaseAuth

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
                Task {
                    let rupees = Int(amountInInr) ?? 1
                    let paise = max(rupees, 1) * 100
                    if let uid = Auth.auth().currentUser?.uid,
                       let billId = try? await BillsService.shared.createBill(userId: uid, amountPaise: paise) {
                        await vm.startPayment(amountPaise: paise, billId: billId)
                    } else {
                        vm.lastResultMessage = "Sign in required"
                    }
                }
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
        .fullScreenCover(isPresented: $vm.showSuccessScreen) {
            if let payment = vm.successPayment {
                NavigationView {
                    PaymentSuccessView(
                        payment: payment,
                        payeeName: vm.successPayeeName,
                        coinsEarned: vm.successCoinsEarned
                    )
                }
            }
        }
    }
}


