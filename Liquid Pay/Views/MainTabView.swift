import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { TransactionsView() }
                .tabItem { Label("Transactions", systemImage: "clock") }

            NavigationStack { PayView() }
                .tabItem { Label("Pay", systemImage: "plus.circle") }

            NavigationStack { RewardsView() }
                .tabItem { Label("Rewards", systemImage: "star") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}


