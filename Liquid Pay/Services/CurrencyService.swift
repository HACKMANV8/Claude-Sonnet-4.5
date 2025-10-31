import Foundation
import Combine

@MainActor
final class CurrencyService: ObservableObject {
    static let shared = CurrencyService()
    
    @Published var rates: [CurrencyRate] = []
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var refreshTimer: Timer?
    // Use exchangerate.host (no API key required, reliable)
    private let baseURL = "https://api.exchangerate.host/latest?base=INR"
    
    // Currency metadata
    private let currencyInfo: [String: (name: String, symbol: String)] = [
        "USD": ("US Dollar", "$"),
        "EUR": ("Euro", "€"),
        "GBP": ("British Pound", "£"),
        "JPY": ("Japanese Yen", "¥"),
        "AUD": ("Australian Dollar", "A$"),
        "CAD": ("Canadian Dollar", "C$"),
        "CHF": ("Swiss Franc", "Fr"),
        "CNY": ("Chinese Yuan", "¥"),
        "AED": ("UAE Dirham", "د.إ"),
        "SGD": ("Singapore Dollar", "S$"),
        "HKD": ("Hong Kong Dollar", "HK$"),
        "NZD": ("New Zealand Dollar", "NZ$"),
        "SEK": ("Swedish Krona", "kr"),
        "KRW": ("South Korean Won", "₩"),
        "MYR": ("Malaysian Ringgit", "RM"),
        "THB": ("Thai Baht", "฿"),
        "ZAR": ("South African Rand", "R"),
        "BRL": ("Brazilian Real", "R$"),
        "MXN": ("Mexican Peso", "Mex$"),
        "RUB": ("Russian Ruble", "₽")
    ]
    
    private init() {
        loadCachedRates()
    }
    
    func startAutoRefresh() {
        // Refresh every 30 minutes
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchRates()
            }
        }
        
        // Fetch immediately if no recent data
        if lastUpdated == nil || Date().timeIntervalSince(lastUpdated ?? Date()) > 1800 {
            Task {
                await fetchRates()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func fetchRates() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let url = URL(string: baseURL) else {
                throw NSError(domain: "CurrencyService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "CurrencyService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
            }
            
            let decoder = JSONDecoder()
            var newRates: [CurrencyRate] = []
            
            // Try exchangerate.host schema first
            if let host = try? decoder.decode(ExchangeRateHostResponse.self, from: data),
               let ratesDict = host.rates {
                // host returns target-per-INR; for display we want INR per 1 target unit → invert
                for (code, unitPerINR) in ratesDict {
                    if let info = currencyInfo[code], unitPerINR > 0 {
                        let inrPerUnit = 1.0 / unitPerINR
                        newRates.append(CurrencyRate(code: code, name: info.name, rate: inrPerUnit, symbol: info.symbol))
                    }
                }
            } else if let legacy = try? decoder.decode(ExchangeRateResponse.self, from: data),
                      let ratesDict = legacy.rates {
                // Legacy schema assumed the same direction (target-per-INR); invert
                for (code, unitPerINR) in ratesDict {
                    if let info = currencyInfo[code], unitPerINR > 0 {
                        let inrPerUnit = 1.0 / unitPerINR
                        newRates.append(CurrencyRate(code: code, name: info.name, rate: inrPerUnit, symbol: info.symbol))
                    }
                }
            } else {
                throw NSError(domain: "CurrencyService", code: 422, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])
            }
            
            // Sort by code
            newRates.sort { $0.code < $1.code }
            
            self.rates = newRates
            self.lastUpdated = Date()
            
            // Cache the rates
            cacheRates(newRates)
            
            isLoading = false
        } catch {
            errorMessage = "Failed to fetch rates: \(error.localizedDescription)"
            isLoading = false
            print("Currency fetch error: \(error)")
        }
    }
    
    private func cacheRates(_ rates: [CurrencyRate]) {
        if let encoded = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(encoded, forKey: "cached_currency_rates")
            UserDefaults.standard.set(Date(), forKey: "cached_currency_timestamp")
        }
    }
    
    private func loadCachedRates() {
        if let data = UserDefaults.standard.data(forKey: "cached_currency_rates"),
           let cached = try? JSONDecoder().decode([CurrencyRate].self, from: data) {
            self.rates = cached
            self.lastUpdated = UserDefaults.standard.object(forKey: "cached_currency_timestamp") as? Date
        }
    }
    
    func getRate(for code: String) -> CurrencyRate? {
        rates.first { $0.code == code }
    }
    
    func convert(amount: Double, from: String, to: String) -> Double? {
        guard let fromRate = getRate(for: from), let toRate = getRate(for: to) else {
            return nil
        }
        // Convert to INR first, then to target currency
        let inINR = amount / fromRate.rate
        return inINR * toRate.rate
    }
}

