import Foundation

final class UPIPrefsService {
    static let shared = UPIPrefsService()
    private let defaults = UserDefaults.standard
    private let keyPrefix = "upi_pref_"

    // Generate a stable key for a contact using primary phone if available, else contact id
    func key(for contact: ContactInfo) -> String {
        if let phone = contact.phoneNumbers.first, !phone.isEmpty {
            return keyPrefix + normalizePhone(phone)
        }
        return keyPrefix + contact.id
    }

    func savedUPI(for contact: ContactInfo) -> String? {
        defaults.string(forKey: key(for: contact))
    }

    func saveUPI(_ upi: String, for contact: ContactInfo) {
        defaults.set(upi, forKey: key(for: contact))
    }

    func saveUPI(_ upi: String, key: String) {
        defaults.set(upi, forKey: key)
    }

    func normalizePhone(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        return digits
    }
}


