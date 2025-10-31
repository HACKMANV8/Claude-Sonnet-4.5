import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    @StateObject private var payVM = PaymentViewModel()
    @State private var amountInInr: String = "1"

    var body: some View {
        VStack(spacing: 20) {
            Text("Dashboard").font(.largeTitle)

            if let phone = Auth.auth().currentUser?.phoneNumber {
                Text("Signed in as: \(phone)").font(.subheadline)
            }

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
                    // Create a bill record first
                    if let uid = Auth.auth().currentUser?.uid {
                        if let billId = try? await BillsService.shared.createBill(userId: uid, amountPaise: paise) {
                            payVM.startPayment(amountPaise: paise, orderId: nil, billId: billId)
                        } else {
                            payVM.lastResultMessage = "Failed to create bill"
                        }
                        // Recording of final status will happen via callback in PaymentViewModel for now
                    } else {
                        payVM.lastResultMessage = "Not signed in"
                    }
                }
            } label: {
                Text("Create Bill & Pay")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if let msg = payVM.lastResultMessage {
                Text(msg).foregroundColor(.secondary)
            }

            NavigationLink("View Bills", destination: BillsListView())

            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log Out") { try? Auth.auth().signOut() }
            }
        }
    }
}


