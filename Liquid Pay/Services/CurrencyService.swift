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
    private let baseURL = "https://api.exchangerate-api.com/v4/latest/INR"
    
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
            let result = try decoder.decode(ExchangeRateResponse.self, from: data)
            
            // Convert to CurrencyRate objects
            var newRates: [CurrencyRate] = []
            for (code, rate) in result.rates {
                if let info = currencyInfo[code] {
                    newRates.append(CurrencyRate(
                        code: code,
                        name: info.name,
                        rate: rate,
                        symbol: info.symbol
                    ))
                }
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

