import SwiftUI

extension Notification.Name {
    static let switchTab = Notification.Name("LP_SwitchTab")
    static let paymentCompleted = Notification.Name("LP_PaymentCompleted")
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            NavigationStack { TransactionsView() }
                .tabItem { Label("Transactions", systemImage: "clock") }
                .tag(1)

            NavigationStack { PayView() }
                .tabItem { Label("Pay", systemImage: "qrcode") }
                .tag(2)

            NavigationStack { RewardsView() }
                .tabItem { Label("Rewards", systemImage: "star") }
                .tag(3)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { note in
            if let idx = note.userInfo?["index"] as? Int { selectedTab = idx }
        }
    }
}


