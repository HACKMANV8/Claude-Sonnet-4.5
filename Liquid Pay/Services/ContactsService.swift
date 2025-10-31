import Foundation
@preconcurrency import Contacts
import UIKit
import SwiftUI
import Combine

struct ContactInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let upiId: String?
    let initials: String
    
    var displayName: String {
        name.isEmpty ? (phoneNumbers.first ?? "Unknown") : name
    }
    
    var primaryUPI: String? {
        // Check if any phone number or email looks like UPI ID
        var allIds = phoneNumbers + emailAddresses
        if let upi = upiId {
            allIds.append(upi)
        }
        return allIds.first { $0.contains("@") }
    }
}

@MainActor
final class ContactsService: ObservableObject {
    static let shared = ContactsService()
    
    @Published var contacts: [ContactInfo] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    
    // Create CNContactStore only when needed to avoid unused initialization warnings
    // and to keep access localized to the requesting context
    
    init() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await CNContactStore().requestAccess(for: .contacts)
            authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            if granted {
                await fetchContacts()
            }
            return granted
        } catch {
            errorMessage = "Failed to request contacts access: \(error.localizedDescription)"
            return false
        }
    }
    
    func fetchContacts() async {
        // Check current status
        let currentStatus = CNContactStore.authorizationStatus(for: .contacts)
        authorizationStatus = currentStatus
        
        guard currentStatus == .authorized else {
            if currentStatus == .notDetermined {
                _ = await requestAccess()
                return
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactImageDataKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName
        
        do {
            let fetchedContacts: [ContactInfo] = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var results: [ContactInfo] = []
                    do {
                        // Recreate store and request locally to avoid capturing non-Sendable values
                        let localStore = CNContactStore()
                        let localRequest = CNContactFetchRequest(keysToFetch: keys)
                        localRequest.sortOrder = .givenName

                        try localStore.enumerateContacts(with: localRequest) { contact, stop in
                            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty || !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty else {
                                return
                            }
                            let phoneNumbers = contact.phoneNumbers.compactMap { $0.value.stringValue }
                            let emailAddresses = contact.emailAddresses.compactMap { $0.value as String }
                            let upiId = (phoneNumbers + emailAddresses).first {
                                $0.contains("@") && ($0.contains("upi") || $0.contains("paytm") || $0.contains("gpay") || $0.contains("okaxis") || $0.contains("ybl") || $0.contains("axl") || $0.contains("ibl"))
                            }

                            // Local initials generator (non-isolated)
                            func generateInitialsLocal(_ text: String) -> String {
                                let components = text.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                                if components.count >= 2 {
                                    let first = String(components[0].prefix(1)).uppercased()
                                    let last = String(components[components.count - 1].prefix(1)).uppercased()
                                    return first + last
                                } else if !components.isEmpty {
                                    let first = String(components[0].prefix(1)).uppercased()
                                    if components[0].count > 1 {
                                        let second = String(components[0].suffix(1)).uppercased()
                                        return first + second
                                    }
                                    return first
                                }
                                return "?"
                            }

                            let initials = generateInitialsLocal(name.isEmpty ? (phoneNumbers.first ?? emailAddresses.first ?? "") : name)
                            let contactInfo = ContactInfo(
                                id: contact.identifier,
                                name: name.isEmpty ? (phoneNumbers.first ?? emailAddresses.first ?? "Unknown") : name,
                                phoneNumbers: phoneNumbers,
                                emailAddresses: emailAddresses,
                                upiId: upiId,
                                initials: initials
                            )
                            results.append(contactInfo)
                        }
                        continuation.resume(returning: results.sorted { $0.name < $1.name })
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            contacts = fetchedContacts
        } catch {
            errorMessage = "Failed to fetch contacts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func generateInitials(from text: String) -> String {
        let components = text.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
        if components.count >= 2 {
            let first = String(components[0].prefix(1)).uppercased()
            let last = String(components[components.count - 1].prefix(1)).uppercased()
            return first + last
        } else if !components.isEmpty {
            let first = String(components[0].prefix(1)).uppercased()
            if components[0].count > 1 {
                let second = String(components[0].suffix(1)).uppercased()
                return first + second
            }
            return first
        }
        return "?"
    }
    
    static func getContactAvatarColor(for contact: ContactInfo) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .red, .yellow, .teal, .indigo
        ]
        let hash = abs(contact.id.hashValue)
        return colors[hash % colors.count]
    }
}

