import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()

    private func rupees(_ paise: Int) -> String { "₹\(paise/100)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    StatCard(title: "Total Spent", value: rupees(vm.totalPaidPaise), color: .blue)
                    StatCard(title: "Last Payment", value: vm.recentPayments.first?.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "—", color: .green)
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
                    Text("Recent Transactions").font(.headline)
                    ForEach(vm.recentPayments.prefix(5)) { p in
                        HStack {
                            Text(rupees(p.amountPaise)).bold()
                            Spacer()
                            Text(p.status.capitalized)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(p.status == "success" ? Color.green.opacity(0.15) : (p.status == "failed" ? Color.red.opacity(0.15) : Color.orange.opacity(0.15)))
                                .foregroundColor(p.status == "success" ? .green : (p.status == "failed" ? .red : .orange))
                                .cornerRadius(6)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .onAppear { vm.startListening() }
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


