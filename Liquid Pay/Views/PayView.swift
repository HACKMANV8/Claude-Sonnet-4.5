import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PayView: View {
    @StateObject private var vm = PaymentViewModel()
    @State private var amountInInr: String = ""
    @State private var activeVouchers: [Voucher] = []
    @State private var vouchersListener: ListenerRegistration?
    @State private var selectedVoucher: Voucher?
    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Amount (INR)")
                TextField("1", text: $amountInInr)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            if !activeVouchers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apply Voucher").font(.caption).foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(activeVouchers) { v in
                                let isSelected = selectedVoucher?.id == v.id
                                Button {
                                    selectedVoucher = isSelected ? nil : v
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(v.code).font(.caption).bold()
                                        Text("₹\(v.valuePaise/100)").font(.caption2)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(isSelected ? Color.green.opacity(0.2) : Color(.secondarySystemBackground))
                                    .foregroundColor(isSelected ? .green : .primary)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }

            Button {
                Task {
                    guard let rupees = Int(amountInInr), rupees >= 1 else {
                        errorAlertMessage = "Enter a valid amount (₹1 or more)"
                        showErrorAlert = true
                        return
                    }
                    var paise = rupees * 100
                    if let v = selectedVoucher {
                        paise = max(100, paise - v.valuePaise)
                    }
                    
                    guard let uid = Auth.auth().currentUser?.uid else {
                        errorAlertMessage = "Please sign in to continue"
                        showErrorAlert = true
                        return
                    }
                    
                    do {
                        let billId = try await BillsService.shared.createBill(userId: uid, amountPaise: paise)
                        var notes: [String: String] = [:]
                        if let v = selectedVoucher { notes["voucherId"] = v.id }
                        await vm.startPayment(amountPaise: paise, billId: billId, notes: notes)
                    } catch {
                        errorAlertMessage = "Failed to create payment: \(error.localizedDescription)"
                        showErrorAlert = true
                    }
                }
            } label: {
                Text("Pay with Razorpay")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if let msg = vm.lastResultMessage {
                Text(msg).foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Pay")
        .onAppear {
            if let uid = Auth.auth().currentUser?.uid {
                vouchersListener?.remove(); vouchersListener = nil
                vouchersListener = RewardsService.shared.listenActiveVouchers(uid: uid) { vouchers in
                    activeVouchers = vouchers
                    if selectedVoucher != nil && !(vouchers.contains(where: { $0.id == selectedVoucher!.id })) {
                        selectedVoucher = nil
                    }
                }
            }
        }
        .onDisappear { vouchersListener?.remove(); vouchersListener = nil }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorAlertMessage)
        }
    }
}


