import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()

    private func rupees(_ paise: Int) -> String { Currency.formatPaise(paise) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    StatCard(title: "Total Spent", value: rupees(vm.totalPaidPaise), color: .blue)
                    StatCard(title: "This Month Spent", value: rupees(vm.thisMonthPaidPaise), color: .purple)
                }

                HStack(spacing: 16) {
                    StatCard(title: "Last Payment", value: lastPaymentText, color: .green)
                }

                NavigationLink(destination: PayView()) {
                    Text("Pay Now")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 7 Days").font(.caption).foregroundColor(.secondary)
                    SparklineView(values: vm.last7DaysPaise.map { Double($0) / 100.0 })
                        .frame(height: 48)
                        .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Home")
        .onAppear { vm.startListening() }
    }

    private var lastPaymentText: String {
        if let amount = vm.lastPaymentAmountPaise, let status = vm.lastPaymentStatus {
            let statusPretty = status.capitalized
            return "\(rupees(amount)) — \(statusPretty)"
        }
        if let d = vm.lastPaymentDate {
            return d.formatted(date: .abbreviated, time: .shortened)
        }
        return "—"
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }
}


