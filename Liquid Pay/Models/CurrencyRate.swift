import Foundation

struct CurrencyRate: Identifiable, Codable {
    let id: String
    let code: String
    let name: String
    let rate: Double
    let symbol: String
    
    init(code: String, name: String, rate: Double, symbol: String) {
        self.id = code
        self.code = code
        self.name = name
        self.rate = rate
        self.symbol = symbol
    }
}

// Legacy schema (exchangerate-api v4) - kept for compatibility if used
struct ExchangeRateResponse: Codable {
    let result: String?
    let base_code: String?
    let rates: [String: Double]?
    let time_last_update_unix: Int?
}

// exchangerate.host schema (preferred)
struct ExchangeRateHostResponse: Codable {
    let success: Bool?
    let base: String?
    let date: String?
    let rates: [String: Double]?
}

