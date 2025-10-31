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
    @FocusState private var focusedField: Field?
    private enum Field { case upi, amount, note }
    
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
                
                HStack(spacing: 8) {
                    TextField("e.g., username@provider (@ybl, @oksbi)", text: $upiId)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .textContentType(.username)
                        .focused($focusedField, equals: .upi)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                    Button {
                        if let paste = UIPasteboard.general.string, !paste.isEmpty { upiId = paste }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                }
                .overlay(
                    HStack {
                        Spacer()
                        if !upiId.isEmpty {
                            Button { upiId = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                                .padding(.trailing, 8)
                        }
                    }
                )
            }
            
            if upiId.contains("@"), !upiId.contains("@ybl") && !upiId.contains("@oksbi") && !upiId.contains("@okaxis") && !upiId.contains("@okhdfcbank") && !upiId.contains("@okicici") && !upiId.contains("@paytm") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Common providers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let suffixes = ["ybl","oksbi","okaxis","okhdfcbank","okicici","paytm"]
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suffixes, id: \.self) { sfx in
                                Button {
                                    if let at = upiId.firstIndex(of: "@") {
                                        upiId = String(upiId[..<at]) + "@" + sfx
                                    }
                                } label: {
                                    Text("@\(sfx)")
                                        .font(.caption)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
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
                        .focused($focusedField, equals: .amount)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                HStack(spacing: 8) {
                    ForEach([100,200,500,1000], id: \.self) { val in
                        Button { amountInInr = String(val) } label: {
                            Text("₹\(val)")
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Note field (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Note (optional)")
                    .font(.headline)
                TextField("Add a message for the recipient", text: $noteText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .note)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
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
            
            VStack(spacing: 8) {
                Button {
                    Task { await processPayment() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Pay Now")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: .blue.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .disabled(upiId.isEmpty || amountInInr.isEmpty)
                .opacity(upiId.isEmpty || amountInInr.isEmpty ? 0.6 : 1)
                if let v = selectedVoucher, let rupees = Int(amountInInr), rupees > 0 {
                    let discount = min(v.valuePaise, rupees * 100)
                    let final = max(100, rupees * 100 - discount)
                    Text("Payable: \(Currency.formatPaise(final)) after voucher")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let msg = vm.lastResultMessage {
                Text(msg).foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
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
                .interactiveDismissDisabled(true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .paymentCompleted)) { _ in
            // Dismiss PayByUPIView only when user explicitly closes success screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
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

