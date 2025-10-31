import Foundation

// Pair-based rate model for displaying conversions like USD → INR
struct CurrencyPairRate: Identifiable, Codable, Equatable {
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
    
    var id: String { "\(fromCurrency)_\(toCurrency)" }
}

extension CurrencyPairRate {
    static let defaultPairs: [(String, String)] = [
        ("USD", "INR"),
        ("GBP", "INR"),
        ("EUR", "INR")
    ]
    
    static func mockRates() -> [CurrencyPairRate] {
        return [
            CurrencyPairRate(fromCurrency: "USD", toCurrency: "INR", rate: 83.25),
            CurrencyPairRate(fromCurrency: "GBP", toCurrency: "INR", rate: 105.80),
            CurrencyPairRate(fromCurrency: "EUR", toCurrency: "INR", rate: 89.95)
        ]
    }
}

// Codable response for exchangerate-api.com
struct ERACurrencyRateResponse: Codable {
    let rates: [String: Double]
    let base: String
    let date: String
}

