import SwiftUI
import Contacts

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @StateObject private var contactsService = ContactsService.shared
    @State private var showPaySheet: Bool = false
    @State private var selectedContact: ContactInfo?
    @State private var showContactSearch: Bool = false

    private func rupees(_ paise: Int) -> String { Currency.formatPaise(paise) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    StatCard(title: "Total Spent", value: rupees(vm.totalPaidPaise), color: .blue)
                    StatCard(title: "This Month Spent", value: rupees(vm.thisMonthPaidPaise), color: .purple)
                }

                HStack(spacing: 16) {
                    StatCard(title: "Last Payment", value: lastPaymentText, color: .green)
                }

                // People Section (double row + search tile)
                if !contactsService.contacts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("People")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)

                        let rows = [GridItem(.fixed(96)), GridItem(.fixed(96))]
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: rows, spacing: 16) {
                                ForEach(contactsService.contacts.prefix(16)) { contact in
                                    ContactAvatarView(contact: contact)
                                        .onTapGesture {
                                            selectedContact = contact
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                showPaySheet = true
                                            }
                                        }
                                }

                                // Search tile at the end
                                ContactSearchTile {
                                    showContactSearch = true
                                }
                            }
                            .padding(.horizontal, 4)
                            .frame(minHeight: 200)
                }
                    }
                    .padding(.vertical, 8)
                } else if contactsService.authorizationStatus == .notDetermined || contactsService.authorizationStatus == .denied {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("People")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Button {
                            Task {
                                _ = await contactsService.requestAccess()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Connect Contacts")
                                        .font(.headline)
                                    Text("Quick access to send money")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        .padding()
                            .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
                    }
                    .padding(.vertical, 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 7 Days").font(.caption).foregroundColor(.secondary)
                    SparklineView(values: vm.last7DaysPaise.map { Double($0) / 100.0 })
                        .frame(height: 48)
                        .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(12)
                
                // Global Rates Section
                GlobalRatesView()
            }
            .padding()
        }
        .navigationTitle("Home")
        .onAppear {
            vm.startListening()
            if contactsService.authorizationStatus == .authorized {
                Task {
                    await contactsService.fetchContacts()
                }
            }
        }
        .sheet(isPresented: $showPaySheet) {
            if let contact = selectedContact {
                NavigationView {
                    PayByUPIView(
                        vouchers: [],
                        selectedVoucher: .constant(nil),
                        initialUPIId: initialUPI(for: contact),
                        initialAmount: "",
                        contactName: contact.displayName,
                        upiSaveKey: UPIPrefsService.shared.key(for: contact)
                    )
                }
            }
        }
        .sheet(isPresented: $showContactSearch) {
            ContactSearchSheet(contacts: contactsService.contacts) { contact in
                // Dismiss search first, then show payment sheet with a small delay
                showContactSearch = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedContact = contact
                    showPaySheet = true
                }
            }
        }
    }

    private var lastPaymentText: String {
        if let amount = vm.lastPaymentAmountPaise, let d = vm.lastPaymentDate {
            return "\(rupees(amount)) — \(d.formatted(date: .abbreviated, time: .shortened))"
        }
        if let amount = vm.lastPaymentAmountPaise {
            return rupees(amount)
        }
        if let d = vm.lastPaymentDate {
            return d.formatted(date: .abbreviated, time: .shortened)
        }
        return "—"
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }
}

// MARK: - Contact Avatar View
private struct ContactAvatarView: View {
    let contact: ContactInfo
    @State private var avatarColor: Color = .blue
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer ring
                Circle()
                    .fill(avatarColor.opacity(0.25))
                    .frame(width: 64, height: 64)
                // Inner circle
                Circle()
                    .fill(avatarColor)
                    .frame(width: 56, height: 56)
                
                Text(contact.initials)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(contact.displayName)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 70)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            avatarColor = ContactsService.getContactAvatarColor(for: contact)
        }
    }
}

// MARK: - Contact Search Tile
private struct ContactSearchTile: View {
    var onTap: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(Color(.secondarySystemBackground)).frame(width: 64, height: 64)
                Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1).frame(width: 64, height: 64)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text("Search")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - Contact Search Sheet
private struct ContactSearchSheet: View {
    let contacts: [ContactInfo]
    var onSelect: (ContactInfo) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    private var displayed: [ContactInfo] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty { return contacts }
        let q = searchText.lowercased()
        return contacts.filter { c in
            c.displayName.lowercased().contains(q) ||
            c.phoneNumbers.joined(separator: " ").contains(q)
        }
    }
    
    var body: some View {
        NavigationView {
            List(displayed, id: \.id) { c in
                Button {
                    onSelect(c)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Circle().fill(ContactsService.getContactAvatarColor(for: c)).frame(width: 36, height: 36)
                            .overlay(Text(c.initials).font(.caption).foregroundColor(.white))
                        VStack(alignment: .leading) {
                            Text(c.displayName).font(.body)
                            if let first = c.phoneNumbers.first { Text(first).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .navigationTitle("Search Contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}

// MARK: - Helpers
private extension HomeView {
    func initialUPI(for contact: ContactInfo) -> String {
        if let saved = UPIPrefsService.shared.savedUPI(for: contact) { return saved }
        if let primary = contact.primaryUPI { return primary }
        if let phone = contact.phoneNumbers.first, !phone.isEmpty {
            let digits = UPIPrefsService.shared.normalizePhone(phone)
            return digits + "@"
        }
        return ""
    }
}


