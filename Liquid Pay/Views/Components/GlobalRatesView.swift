import SwiftUI

struct GlobalRatesView: View {
    @StateObject private var rateManager = CurrencyRateManager.shared
    @State private var showEditSheet: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Single card container with gradient background
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Global Rates")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Edit button
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Rates - Horizontal centered
                if rateManager.currencyRates.isEmpty {
                    VStack(spacing: 8) {
                        if rateManager.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding()
                        } else {
                            Text("Tap refresh to load rates")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                } else {
                    HStack(spacing: 24) {
                        ForEach(rateManager.currencyRates) { rate in
                            CompactPairRateView(rate: rate)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                if let error = rateManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.3, blue: 0.4), Color(red: 0.05, green: 0.2, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
        .onAppear {
            rateManager.refresh()
        }
        .sheet(isPresented: $showEditSheet) {
            PairSelectionSheet(currentPairs: rateManager.selectedPairs) { newPairs in
                rateManager.setSelectedPairs(newPairs)
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "\(mins)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

// MARK: - Compact Pair Rate View (for horizontal layout)
private struct CompactPairRateView: View {
    let rate: CurrencyPairRate
    
    private func symbol(for code: String) -> String {
        switch code {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "AED": return "د.إ"
        case "SGD": return "S$"
        default: return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(rate.fromCurrency)/\(rate.toCurrency)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(formatRate(rate.rate, code: rate.toCurrency))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func formatRate(_ r: Double, code: String) -> String {
        let sym = symbol(for: code)
        if r >= 1 { return String(format: "\(sym)%.2f", r) }
        return String(format: "\(sym)%.4f", r)
    }
}

// MARK: - Pair Selection Sheet (simple: choose base → INR pairs)
private struct PairSelectionSheet: View {
    let currentPairs: [(String, String)]
    var onSave: ([(String, String)]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBases: Set<String> = []
    @State private var searchText: String = ""
    
    private let toCurrency = "INR"
    private let availableCodes: [String] = [
        "USD","EUR","GBP","AUD","CAD","JPY","AED","SGD","CHF","CNY","NZD","SEK","KRW","MYR","THB","ZAR","BRL","MXN"
    ]
    
    private var filteredCodes: [String] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return availableCodes }
        return availableCodes.filter { $0.lowercased().contains(q) }
    }
    
    var body: some View {
        NavigationView {
            List(filteredCodes, id: \.self) { code in
                Button {
                    toggle(code)
                } label: {
                    HStack {
                        Text("\(code) → \(toCurrency)").font(.body)
                        Spacer()
                        Image(systemName: selectedBases.contains(code) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedBases.contains(code) ? .green : .secondary)
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Pairs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { selectedBases = Set(["USD","GBP","EUR"]) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let pairs = selectedBases.map { ($0, toCurrency) }
                        onSave(pairs.sorted { $0.0 < $1.0 })
                        dismiss()
                    }
                }
            }
            .onAppear {
                let bases = currentPairs.filter { $0.1 == toCurrency }.map { $0.0 }
                if bases.isEmpty { selectedBases = Set(["USD","GBP","EUR"]) }
                else { selectedBases = Set(bases) }
            }
        }
    }
    
    private func toggle(_ code: String) {
        if selectedBases.contains(code) { selectedBases.remove(code) }
        else if selectedBases.count < 6 { selectedBases.insert(code) }
    }
}

