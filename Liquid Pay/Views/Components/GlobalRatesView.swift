import SwiftUI

struct GlobalRatesView: View {
    @StateObject private var currencyService = CurrencyService.shared
    @AppStorage("selected_currencies") private var selectedCurrenciesJSON: String = ""
    @State private var showEditSheet: Bool = false
    @State private var selectedCurrencies: [String] = ["USD", "EUR", "GBP"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Global Rates")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let lastUpdated = currencyService.lastUpdated {
                        Text("Updated \(timeAgo(lastUpdated))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Refresh button
                    Button {
                        Task {
                            await currencyService.fetchRates()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .rotationEffect(.degrees(currencyService.isLoading ? 360 : 0))
                            .animation(currencyService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: currencyService.isLoading)
                    }
                    .disabled(currencyService.isLoading)
                    
                    // Edit button
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Rates Grid
            if currencyService.rates.isEmpty {
                VStack(spacing: 8) {
                    if currencyService.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Text("Tap refresh to load rates")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(getDisplayedRates()) { rate in
                        RateCard(rate: rate)
                    }
                }
            }
            
            if let error = currencyService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
        }
        .onAppear {
            loadSelectedCurrencies()
            currencyService.startAutoRefresh()
        }
        .onDisappear {
            currencyService.stopAutoRefresh()
        }
        .sheet(isPresented: $showEditSheet) {
            CurrencySelectionSheet(
                selectedCurrencies: $selectedCurrencies,
                availableRates: currencyService.rates
            )
            .onDisappear {
                saveSelectedCurrencies()
            }
        }
    }
    
    private func getDisplayedRates() -> [CurrencyRate] {
        let selected = selectedCurrencies.isEmpty ? ["USD", "EUR", "GBP"] : selectedCurrencies
        return currencyService.rates.filter { selected.contains($0.code) }
    }
    
    private func loadSelectedCurrencies() {
        if let data = selectedCurrenciesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            selectedCurrencies = decoded
        } else {
            selectedCurrencies = ["USD", "EUR", "GBP"]
        }
    }
    
    private func saveSelectedCurrencies() {
        if let encoded = try? JSONEncoder().encode(selectedCurrencies),
           let json = String(data: encoded, encoding: .utf8) {
            selectedCurrenciesJSON = json
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

// MARK: - Rate Card
private struct RateCard: View {
    let rate: CurrencyRate
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(rate.code)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Text(rate.symbol)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text(formatRate(rate.rate))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(rate.name)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatRate(_ rate: Double) -> String {
        if rate >= 1 {
            return String(format: "₹%.2f", rate)
        } else {
            return String(format: "₹%.4f", rate)
        }
    }
}

// MARK: - Currency Selection Sheet
private struct CurrencySelectionSheet: View {
    @Binding var selectedCurrencies: [String]
    let availableRates: [CurrencyRate]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    private var displayedRates: [CurrencyRate] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return availableRates
        }
        let query = searchText.lowercased()
        return availableRates.filter {
            $0.code.lowercased().contains(query) ||
            $0.name.lowercased().contains(query)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Info banner
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Select up to 6 currencies to display")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(selectedCurrencies.count)/6")
                        .font(.caption)
                        .foregroundColor(selectedCurrencies.count >= 6 ? .red : .secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                List {
                    ForEach(displayedRates) { rate in
                        Button {
                            toggleSelection(rate.code)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(rate.code)
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(rate.symbol)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    Text(rate.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedCurrencies.contains(rate.code) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 20))
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 20))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search currencies")
            }
            .navigationTitle("Select Currencies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedCurrencies = ["USD", "EUR", "GBP"]
                    }
                }
            }
        }
    }
    
    private func toggleSelection(_ code: String) {
        if selectedCurrencies.contains(code) {
            selectedCurrencies.removeAll { $0 == code }
        } else {
            if selectedCurrencies.count < 6 {
                selectedCurrencies.append(code)
            }
        }
    }
}

