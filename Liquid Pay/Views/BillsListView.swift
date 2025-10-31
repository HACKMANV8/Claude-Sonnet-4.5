import SwiftUI

struct BillsListView: View {
    @StateObject private var vm = BillsViewModel()
    @State private var newAmount: String = ""
    @State private var showCreate: Bool = false

    var body: some View {
        List {
            if vm.bills.isEmpty && !vm.isLoading {
                Text("No bills yet. Tap + to create one.")
                    .foregroundColor(.secondary)
            }
            ForEach(vm.bills) { bill in
                NavigationLink(destination: BillDetailView(bill: bill)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(Currency.formatPaise(bill.amountPaise)).font(.headline)
                            if let date = bill.createdAt {
                                Text(date.formatted()).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        StatusChip(text: bill.status)
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if vm.isLoading { ProgressView() }
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newAmount = ""
                    showCreate = true
                } label: { Image(systemName: "plus") }
            }
        }
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .alert("Create Bill", isPresented: $showCreate) {
            TextField("Amount in INR", text: $newAmount).keyboardType(.numberPad)
            Button("Create") {
                Task { await vm.createBill(amountInRupees: Int(newAmount) ?? 1) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter an amount (₹)")
        }
    }
}


