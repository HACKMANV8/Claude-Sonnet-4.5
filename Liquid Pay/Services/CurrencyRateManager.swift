import Foundation
import Combine

// ObservableObject manager that fetches rates using Combine and caches selections + data
final class CurrencyRateManager: ObservableObject {
    static let shared = CurrencyRateManager()
    
    // Published outputs for SwiftUI
    @Published private(set) var currencyRates: [CurrencyPairRate] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    
    // Configuration
    private let base: String = "USD"
    private let baseURL: String = "https://api.exchangerate-api.com/v4/latest"
    
    // UserDefaults keys
    private let selectedPairsKey = "selectedCurrencyPairs"
    private let lastUpdateKey = "currencyRatesLastUpdate"
    private let cachedRatesKey = "cachedCurrencyRates"
    
    // Selection (pairs like (from, to))
    @Published private(set) var selectedPairs: [(String, String)] = CurrencyPairRate.defaultPairs
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSelectedPairs()
        loadCachedRates()
        // Preload mock so UI has something while fetching
        if currencyRates.isEmpty {
            currencyRates = CurrencyPairRate.mockRates()
        }
    }
    
    // MARK: - Public API
    func refresh() {
        fetchRatesFromAPI()
    }
    
    func setSelectedPairs(_ pairs: [(String, String)]) {
        selectedPairs = pairs
        saveSelectedPairs()
        // Recompute immediately using cached/latest data if available
        fetchRatesFromAPI()
    }
    
    // MARK: - Fetch
    private func fetchRatesFromAPI() {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "\(baseURL)/\(base)") else {
            fallbackToMockData()
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: ERACurrencyRateResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                if case let .failure(error) = completion {
                    self.errorMessage = "Failed to fetch rates: \(error.localizedDescription)"
                    // Try cache, then fallback
                    if self.currencyRates.isEmpty { self.loadCachedRates() }
                    if self.currencyRates.isEmpty { self.fallbackToMockData() }
                }
            }, receiveValue: { [weak self] response in
                self?.processAPIResponse(response)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Processing
    private func processAPIResponse(_ response: ERACurrencyRateResponse) {
        // response.rates: target-per-USD
        let ratesDict = response.rates
        
        let computed: [CurrencyPairRate] = selectedPairs.compactMap { pair in
            let from = pair.0
            let to = pair.1
            var rate: Double
            if from == base, let toRate = ratesDict[to] { // USD → target
                rate = toRate
            } else if to == base, let fromRate = ratesDict[from] { // X → USD
                guard fromRate > 0 else { return nil }
                rate = 1.0 / fromRate
            } else {
                guard let fromRate = ratesDict[from], let toRate = ratesDict[to], fromRate > 0 else { return nil }
                // Cross rate: (to/USD) / (from/USD)
                rate = toRate / fromRate
            }
            return CurrencyPairRate(fromCurrency: from, toCurrency: to, rate: rate)
        }
        
        currencyRates = computed
        lastUpdated = Date()
        cacheRates()
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Caching
    private func cacheRates() {
        if let data = try? JSONEncoder().encode(currencyRates) {
            UserDefaults.standard.set(data, forKey: cachedRatesKey)
            UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
        }
    }
    
    private func loadCachedRates() {
        if let data = UserDefaults.standard.data(forKey: cachedRatesKey),
           let rates = try? JSONDecoder().decode([CurrencyPairRate].self, from: data) {
            currencyRates = rates
            lastUpdated = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
        }
    }
    
    private func saveSelectedPairs() {
        let pairs = selectedPairs.map { [$0.0, $0.1] }
        if let data = try? JSONEncoder().encode(pairs) {
            UserDefaults.standard.set(data, forKey: selectedPairsKey)
        }
    }
    
    private func loadSelectedPairs() {
        guard let data = UserDefaults.standard.data(forKey: selectedPairsKey),
              let pairs = try? JSONDecoder().decode([[String]].self, from: data) else {
            selectedPairs = CurrencyPairRate.defaultPairs
            return
        }
        selectedPairs = pairs.compactMap { arr in
            guard arr.count == 2 else { return nil }
            return (arr[0], arr[1])
        }
        if selectedPairs.isEmpty { selectedPairs = CurrencyPairRate.defaultPairs }
    }
    
    private func fallbackToMockData() {
        currencyRates = CurrencyPairRate.mockRates()
        lastUpdated = Date()
    }
}

