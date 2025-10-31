import SwiftUI
import Contacts

struct TransactionsView: View {
    @StateObject private var vm = PaymentsViewModel()
    @StateObject private var contactsService = ContactsService.shared
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
                        HStack(spacing: 12) {
                            // Icon based on status
                            Image(systemName: payment.status == "success" ? "checkmark.circle.fill" : payment.status == "failed" ? "xmark.circle.fill" : "clock.fill")
                                .font(.system(size: 24))
                                .foregroundColor(payment.status == "success" ? .green : payment.status == "failed" ? .red : .orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Currency.formatPaise(payment.amountPaise))
                                    .font(.headline)
                                
                                if let recipient = payment.recipient, !recipient.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("To: \(getDisplayName(for: recipient))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        // Show UPI ID if different from display name
                                        if getDisplayName(for: recipient) != recipient {
                                            Text(recipient)
                                                .font(.caption2)
                                                .foregroundColor(.secondary.opacity(0.8))
                                        }
                                    }
                                }
                                
                                if let date = payment.createdAt {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
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
        .onAppear { 
            vm.startListening()
            if contactsService.contacts.isEmpty && contactsService.authorizationStatus == .authorized {
                Task {
                    await contactsService.fetchContacts()
                }
            }
        }
        .onDisappear { vm.stopListening() }
    }
    
    // Helper function to get display name from UPI ID
    private func getDisplayName(for upiId: String) -> String {
        // Extract phone number from UPI ID (format: phone@provider)
        let components = upiId.split(separator: "@")
        guard let phoneNumber = components.first else { return upiId }
        
        let cleanedPhone = String(phoneNumber).filter { $0.isNumber }
        
        // Search contacts for matching phone number
        for contact in contactsService.contacts {
            for contactPhone in contact.phoneNumbers {
                let cleanedContactPhone = contactPhone.filter { $0.isNumber }
                // Check if the last 10 digits match (Indian phone numbers)
                if cleanedPhone.suffix(10) == cleanedContactPhone.suffix(10) {
                    return contact.displayName
                }
            }
        }
        
        // If no contact found, return the UPI ID
        return upiId
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


