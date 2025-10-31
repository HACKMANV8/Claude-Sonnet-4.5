import Foundation

enum Currency {
    private static let inr: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "INR"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    /// Formats paise amount (1/100 INR) into a user-friendly INR string.
    static func formatPaise(_ paise: Int) -> String {
        let rupees = Double(paise) / 100.0
        return inr.string(from: NSNumber(value: rupees)) ?? "₹\(paise/100)"
    }
}


