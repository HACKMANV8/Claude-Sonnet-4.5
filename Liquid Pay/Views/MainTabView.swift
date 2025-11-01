import SwiftUI

extension Notification.Name {
    static let switchTab = Notification.Name("LP_SwitchTab")
    static let paymentCompleted = Notification.Name("LP_PaymentCompleted")
    static let openPayWithUPI = Notification.Name("LP_OpenPayWithUPI")
    static let openReceive = Notification.Name("LP_OpenReceive")
    static let remindersUpdated = Notification.Name("LP_RemindersUpdated")
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
                print("🔔 MainTabView: Received openPayWithUPI notification")
                print("   📋 Raw UPI: '\(upi)'")
                print("   💰 Amount: \(amountPaise) paise (₹\(amountPaise/100))")
                print("   👤 Contact: '\(note.userInfo?["contactName"] as? String ?? "nil")'")
                
                // First dismiss if already showing
                if showQuickPay {
                    print("   ⚠️ Sheet already showing, dismissing first...")
                    showQuickPay = false
                }
                
                // Update values
                self.quickUPI = upi
                self.quickAmountRupees = String(max(1, amountPaise / 100))
                self.quickContact = note.userInfo?["contactName"] as? String
                
                print("✅ MainTabView: Updated state variables")
                print("   quickUPI: '\(self.quickUPI)'")
                print("   quickAmountRupees: '\(self.quickAmountRupees)'")
                print("   quickContact: '\(self.quickContact ?? "nil")'")
                
                selectedTab = 2 // Switch to Pay tab
                
                // Show sheet after a brief delay to ensure values are set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("📱 MainTabView: Opening PayByUPIView sheet now...")
                    print("   Will pass: UPI='\(self.quickUPI)', Amount='\(self.quickAmountRupees)', Contact='\(self.quickContact ?? "nil")'")
                    self.showQuickPay = true
                }
            } else {
                print("❌ MainTabView: Missing UPI or amount in notification userInfo")
                print("   userInfo: \(note.userInfo ?? [:])")
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
            .id("\(quickUPI)_\(quickAmountRupees)_\(quickContact ?? "")") // Force recreation when values change
        }
        .sheet(isPresented: $showReceive) {
            ReceivePaymentView()
        }
    }
}


