import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RewardsView: View {
    @StateObject private var vm = RewardsViewModel()
    @State private var showRedeemSheet: Bool = false
    @State private var redeemAmount: String = ""
    @State private var showVoucherSheet: Bool = false
    @State private var voucherAmountInr: String = ""
    @State private var activeVouchers: [Voucher] = []
    @State private var vouchersListener: ListenerRegistration?

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Liquid Coins").font(.caption).foregroundColor(.secondary)
                Text("\(vm.coinBalance)").font(.system(size: 44, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(12)

            Text("Earn 1 coin per ₹0.01 spent (100 coins = ₹1). Redeem coins anytime.")
                .foregroundColor(.secondary)

            if !vm.recentEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity").font(.caption).foregroundColor(.secondary)
                    ForEach(vm.recentEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entryTitle(entry)).font(.subheadline)
                                if let d = entry.createdAt {
                                    Text(d.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(entry.amount >= 0 ? "+\(entry.amount)" : "\(entry.amount)")
                                .font(.subheadline).bold()
                                .foregroundColor(entry.amount >= 0 ? .green : .red)
                        }
                        .padding(.vertical, 6)
                    }
                    if vm.canLoadMore {
                        Button {
                            Task { await vm.loadMore() }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Load more")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            HStack(spacing: 12) {
                Button {
                    showRedeemSheet = true
                    redeemAmount = ""
                } label: {
                    Text("Redeem Coins")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Button {
                    showVoucherSheet = true
                } label: {
                    Text("Create Voucher")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }

            if !activeVouchers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Vouchers").font(.caption).foregroundColor(.secondary)
                    ForEach(activeVouchers) { v in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.code).font(.subheadline).bold()
                                if let d = v.createdAt {
                                    Text("Created • " + d.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text("₹\(v.valuePaise/100)")
                                .font(.subheadline).bold()
                        }
                        .padding(.vertical, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Rewards")
        .onAppear {
            vm.startListening()
            if let uid = Auth.auth().currentUser?.uid {
                vouchersListener?.remove(); vouchersListener = nil
                vouchersListener = RewardsService.shared.listenActiveVouchers(uid: uid) { vouchers in
                    activeVouchers = vouchers
                }
            }
        }
        .onDisappear { vouchersListener?.remove(); vouchersListener = nil }
        .sheet(isPresented: $showRedeemSheet) {
            RedeemSheetView(coinBalance: vm.coinBalance, onRedeem: { amount, note in
                Task { await vm.redeem(amount: amount, note: note) }
                showRedeemSheet = false
            })
            .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $showVoucherSheet) {
            CreateVoucherSheetView(coinBalance: vm.coinBalance) { inr in
                Task {
                    if let uid = Auth.auth().currentUser?.uid { try? await RewardsService.shared.createVoucher(uid: uid, valuePaise: max(100, inr * 100)) }
                }
                showVoucherSheet = false
            }
            .presentationDetents([.height(260)])
        }
    }

    private func entryTitle(_ entry: CoinEntry) -> String {
        switch entry.type {
        case "earn": return entry.note?.isEmpty == false ? entry.note! : "Earned"
        case "redeem": return entry.note?.isEmpty == false ? entry.note! : "Redeemed"
        default: return entry.note?.isEmpty == false ? entry.note! : entry.type.capitalized
        }
    }
}

private struct CreateVoucherSheetView: View {
    let coinBalance: Int
    var onCreate: (_ amountInRupees: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""

    private var coinsRequired: Int { (Int(amountText) ?? 0) * 100 } // 100 coins = ₹1

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 44, height: 4).padding(.top, 8)
            Text("Create Voucher").font(.headline)
            Text("100 coins = ₹1").foregroundColor(.secondary).font(.subheadline)
            TextField("Amount (₹)", text: $amountText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Cost: \(coinsRequired) coins").foregroundColor(.secondary)
                Spacer()
                Text("Balance: \(coinBalance)").foregroundColor(.secondary)
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    let inr = max(1, Int(amountText) ?? 0)
                    guard coinsRequired <= coinBalance else { return }
                    onCreate(inr)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
private struct RedeemSheetView: View {
    let coinBalance: Int
    var onRedeem: (_ amount: Int, _ note: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var noteText: String = ""

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 44, height: 4).padding(.top, 8)
            Text("Redeem Coins").font(.headline)
            Text("Balance: \(coinBalance)").foregroundColor(.secondary).font(.subheadline)
            TextField("Amount to redeem", text: $amountText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            TextField("Note (optional)", text: $noteText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Redeem") {
                    let amt = Int(amountText) ?? 0
                    guard amt > 0, amt <= coinBalance else { return }
                    onRedeem(amt, noteText.isEmpty ? nil : noteText)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}


