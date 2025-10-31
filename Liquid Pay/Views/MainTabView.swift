import SwiftUI

extension Notification.Name {
    static let switchTab = Notification.Name("LP_SwitchTab")
    static let paymentCompleted = Notification.Name("LP_PaymentCompleted")
    static let openPayWithUPI = Notification.Name("LP_OpenPayWithUPI")
    static let openReceive = Notification.Name("LP_OpenReceive")
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var showQuickPay: Bool = false
    @State private var quickUPI: String = ""
    @State private var quickAmountRupees: String = ""
    @State private var quickContact: String? = nil
    @State private var showReceive: Bool = false

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
        .onReceive(NotificationCenter.default.publisher(for: .openPayWithUPI)) { note in
            if let upi = note.userInfo?["upiId"] as? String,
               let amountPaise = note.userInfo?["amountPaise"] as? Int {
                self.quickUPI = upi
                self.quickAmountRupees = String(max(1, amountPaise / 100))
                self.quickContact = note.userInfo?["contactName"] as? String
                selectedTab = 2 // Switch to Pay tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showQuickPay = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openReceive)) { _ in
            self.showReceive = true
        }
        .sheet(isPresented: $showQuickPay) {
            NavigationView {
                PayByUPIView(
                    vouchers: [],
                    selectedVoucher: .constant(nil),
                    initialUPIId: quickUPI,
                    initialAmount: quickAmountRupees,
                    contactName: quickContact,
                    upiSaveKey: "reminder_\(quickUPI)"
                )
            }
        }
        .sheet(isPresented: $showReceive) {
            ReceivePaymentView()
        }
    }
}


