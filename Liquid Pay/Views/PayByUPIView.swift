import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PayByUPIView: View {
    @StateObject private var vm = PaymentViewModel()
    @State private var upiId: String
    @State private var amountInInr: String
    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @Environment(\.dismiss) private var dismiss
    
    let vouchers: [Voucher]
    @Binding var selectedVoucher: Voucher?
    let contactName: String?
    let upiSaveKey: String?
    
    // Load vouchers independently if not provided
    @State private var loadedVouchers: [Voucher] = []
    @State private var vouchersListener: ListenerRegistration?
    
    // New: optional note for the payment
    @State private var noteText: String = ""
    
    init(vouchers: [Voucher], selectedVoucher: Binding<Voucher?>, initialUPIId: String = "", initialAmount: String = "", contactName: String? = nil, upiSaveKey: String? = nil) {
        self.vouchers = vouchers
        self._selectedVoucher = selectedVoucher
        self._upiId = State(initialValue: initialUPIId)
        self._amountInInr = State(initialValue: initialAmount)
        self.contactName = contactName
        self.upiSaveKey = upiSaveKey
    }
    
    // Computed property to use loaded vouchers if initial vouchers are empty
    private var activeVouchers: [Voucher] {
        vouchers.isEmpty ? loadedVouchers : vouchers
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Contact header if available
            if let name = contactName {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(name.prefix(2)).uppercased())
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paying to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(name)
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("UPI ID")
                    .font(.headline)
                
                TextField("e.g., username@provider (@ybl, @oksbi)", text: $upiId)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .textContentType(.none)
                    .overlay(
                        HStack {
                            Spacer()
                            if !upiId.isEmpty {
                                Button {
                                    upiId = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.trailing, 8)
                            }
                        }
                    )
            }
            
            if upiId.hasSuffix("@") {
                Text("Add your UPI provider after @, e.g., ybl, oksbi, okaxis")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Amount")
                    .font(.headline)
                
                HStack {
                    Text("₹")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    TextField("0", text: $amountInInr)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            // Note field (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Note (optional)")
                    .font(.headline)
                TextField("Add a message for the recipient", text: $noteText)
                    .textFieldStyle(.roundedBorder)
            }
            
            if !activeVouchers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apply Voucher").font(.headline)
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
                                    .background(isSelected ? Color.green.opacity(0.2) : Color(.tertiarySystemBackground))
                                    .foregroundColor(isSelected ? .green : .primary)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            
            if let v = selectedVoucher, let rupees = Int(amountInInr), rupees > 0 {
                let discount = min(v.valuePaise, rupees * 100)
                let final = max(100, rupees * 100 - discount)
                VStack(spacing: 4) {
                    HStack {
                        Text("Original Amount")
                        Spacer()
                        Text("₹\(rupees)")
                    }
                    .foregroundColor(.secondary)
                    HStack {
                        Text("Voucher Discount")
                        Spacer()
                        Text("-₹\(discount/100)")
                    }
                    .foregroundColor(.green)
                    Divider()
                    HStack {
                        Text("Final Amount")
                            .bold()
                        Spacer()
                        Text("₹\(final/100)")
                            .bold()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            Button {
                Task {
                    await processPayment()
                }
            } label: {
                Text("Pay Now")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(upiId.isEmpty || amountInInr.isEmpty)
            
            if let msg = vm.lastResultMessage {
                Text(msg).foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Pay by UPI ID")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load vouchers if not provided
            if vouchers.isEmpty, let uid = Auth.auth().currentUser?.uid {
                vouchersListener?.remove()
                vouchersListener = nil
                vouchersListener = RewardsService.shared.listenActiveVouchers(uid: uid) { vouchers in
                    loadedVouchers = vouchers
                    // Clear selection if voucher is no longer available
                    if let currentVoucher = selectedVoucher,
                       !vouchers.contains(where: { $0.id == currentVoucher.id }) {
                        selectedVoucher = nil
                    }
                }
            }
        }
        .onDisappear {
            vouchersListener?.remove()
            vouchersListener = nil
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorAlertMessage)
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .paymentCompleted)) { _ in
            // Dismiss this flow when payment completes
            dismiss()
        }
    }
    
    private func processPayment() async {
        // Validate UPI ID format
        guard upiId.contains("@"), upiId.count > 3 else {
            errorAlertMessage = "Enter a valid UPI ID (e.g., username@upi)"
            showErrorAlert = true
            return
        }
        
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
            // Save remembered UPI if valid and key provided
            if let key = upiSaveKey, upiId.contains("@") {
                UPIPrefsService.shared.saveUPI(upiId, key: key)
            }
            let billId = try await BillsService.shared.createBill(userId: uid, amountPaise: paise)
            var notes: [String: String] = [:]
            if let v = selectedVoucher { notes["voucherId"] = v.id }
            notes["recipient"] = upiId
            notes["paymentMethod"] = "upi"
            if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notes["note"] = noteText
            }
            
            // Use contact name if available, otherwise use UPI ID
            let payeeName = contactName ?? upiId
            await vm.startPayment(amountPaise: paise, billId: billId, notes: notes, payeeName: payeeName)
        } catch {
            errorAlertMessage = "Failed to create payment: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

