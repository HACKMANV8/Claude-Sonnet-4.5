import SwiftUI

struct TransactionsView: View {
    @StateObject private var vm = PaymentsViewModel()

    var body: some View {
        List {
            if vm.payments.isEmpty && !vm.isLoading {
                Text("No transactions yet.").foregroundColor(.secondary)
            }
            ForEach(vm.payments) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("₹\(p.amountPaise / 100)").font(.headline)
                        if let date = p.createdAt {
                            Text(date.formatted()).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(p.status.capitalized)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(p.status == "success" ? Color.green.opacity(0.15) : (p.status == "failed" ? Color.red.opacity(0.15) : Color.orange.opacity(0.15)))
                        .foregroundColor(p.status == "success" ? .green : (p.status == "failed" ? .red : .orange))
                        .cornerRadius(6)
                }
            }
        }
        .overlay(alignment: .center) {
            if vm.isLoading { ProgressView() }
        }
        .navigationTitle("Transactions")
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
    }
}


