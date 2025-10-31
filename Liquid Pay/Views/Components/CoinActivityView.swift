import SwiftUI
import FirebaseAuth

struct CoinActivityView: View {
    @State private var entries: [CoinEntry] = []
    @State private var balance: Int = 0
    @State private var isLoading: Bool = true
    @State private var lastDoc: Any? = nil
    
    var body: some View {
        List {
            Section(header: Text("Balance: \(balance) coins").foregroundColor(.secondary)) { EmptyView() }
            ForEach(entries) { e in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title(for: e)).font(.subheadline)
                        if let d = e.createdAt { Text(d.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary) }
                    }
                    Spacer()
                    Text(e.amount >= 0 ? "+\(e.amount)" : "\(e.amount)")
                        .font(.subheadline).bold()
                        .foregroundColor(e.amount >= 0 ? .green : .red)
                }
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .navigationTitle("Coin Activity")
        .task { await loadInitial() }
    }
    
    private func loadInitial() async {
        guard let uid = Auth.auth().currentUser?.uid else { isLoading = false; return }
        _ = RewardsService.shared.listenToBalanceAndEntries(uid: uid) { bal, new in
            balance = bal
            entries = new
            isLoading = false
        }
    }
    
    private func title(for entry: CoinEntry) -> String {
        switch entry.type {
        case "daily_reward": return "Daily reward"
        case "game_entry": return entry.note ?? "Game entry"
        case "game_win": return entry.note ?? "Game win"
        case "redeem": return entry.note ?? "Redeemed"
        case "earn": return entry.note ?? "Earned"
        default: return entry.note ?? entry.type.capitalized
        }
    }
}


