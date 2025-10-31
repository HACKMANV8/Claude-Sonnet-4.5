import SwiftUI

struct TransactionsView: View {
    @StateObject private var vm = PaymentsViewModel()
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .newest

    private var displayedPayments: [Payment] {
        let filtered = vm.payments.filter { payment in
            guard !searchText.isEmpty else { return true }
            let query = searchText.lowercased()
            let formattedAmount = Currency.formatPaise(payment.amountPaise).lowercased()
            let plainAmount = String(format: "%.2f", Double(payment.amountPaise) / 100.0).lowercased()

            return formattedAmount.contains(query)
                || plainAmount.contains(query)
                || payment.status.lowercased().contains(query)
                || (payment.razorpayPaymentId?.lowercased().contains(query) ?? false)
                || (payment.billId?.lowercased().contains(query) ?? false)
        }

        switch sortOption {
        case .newest:
            return filtered.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest:
            return filtered.sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
        case .amountHigh:
            return filtered.sorted { $0.amountPaise > $1.amountPaise }
        case .amountLow:
            return filtered.sorted { $0.amountPaise < $1.amountPaise }
        }
    }

    private var emptyStateText: String {
        if vm.payments.isEmpty {
            return "No transactions yet."
        }
        return "No matching transactions."
    }

    var body: some View {
        List {
            if displayedPayments.isEmpty && !vm.isLoading {
                Text(emptyStateText).foregroundColor(.secondary)
            } else {
                ForEach(displayedPayments) { payment in
                    NavigationLink(destination: PaymentReceiptView(payment: payment)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                                Text(Currency.formatPaise(payment.amountPaise)).font(.headline)
                                if let date = payment.createdAt {
                            Text(date.formatted()).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            StatusChip(text: payment.status)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .center) {
            if vm.isLoading { ProgressView() }
        }
        .navigationTitle("Transactions")
        .searchable(text: $searchText, prompt: "Search by amount, status, or ID")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
    }
}

private enum SortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case amountHigh
    case amountLow

    var id: Self { self }

    var title: String {
        switch self {
        case .newest: return "Newest first"
        case .oldest: return "Oldest first"
        case .amountHigh: return "Amount: High to Low"
        case .amountLow: return "Amount: Low to High"
        }
    }

    var systemImage: String {
        switch self {
        case .newest: return "clock.arrow.circlepath"
        case .oldest: return "clock"
        case .amountHigh: return "arrow.down.to.line.compact"
        case .amountLow: return "arrow.up.to.line.compact"
        }
    }
}


