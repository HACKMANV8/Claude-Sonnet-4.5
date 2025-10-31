import SwiftUI
import FirebaseAuth

struct RewardsView: View {
    @State private var coinBalance: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var activeGame: GameInfo? = nil
    @State private var selectedBrand: BrandCard? = nil
    @State private var showRedeemSheet: Bool = false
    @State private var dailyRewardNext: Date? = nil
    
    private var coinValueInInr: String { String(format: "₹%.2f", Double(coinBalance) / 100.0) }
    private let entryFee = 25
    private let winPrize = 50
    private let dailyCapRupees = 50
    
    // Mini-game catalog (URLs can be replaced with hosted HTML5 games)
    private let games: [GameInfo] = [
        GameInfo(title: "Scratch Card", color: .orange, type: .scratch),
        GameInfo(title: "Spin Wheel", color: .purple, type: .spin),
        GameInfo(title: "Tic-Tac-Toe", color: .blue, type: .ttt)
    ]
    
    // Dummy brand cards
    private let brands: [BrandCard] = [
        BrandCard(
            name: "Amazon",
            color: Color(red: 1.00, green: 0.60, blue: 0.00),
            codePrefix: "AMZN",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/512px-Amazon_logo.svg.png",
            coinsRequired: 1000
        ),
        BrandCard(
            name: "Swiggy",
            color: Color(red: 1.00, green: 0.47, blue: 0.12),
            codePrefix: "SWGY",
            logoURL: "https://upload.wikimedia.org/wikipedia/en/thumb/1/12/Swiggy_logo.svg/512px-Swiggy_logo.svg.png",
            coinsRequired: 1500
        ),
        BrandCard(
            name: "Flipkart",
            color: Color(red: 0.03, green: 0.45, blue: 0.91),
            codePrefix: "FLPK",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Flipkart_Logo.png/512px-Flipkart_Logo.png",
            coinsRequired: 2000
        ),
        BrandCard(
            name: "Myntra",
            color: Color(red: 0.96, green: 0.34, blue: 0.57),
            codePrefix: "MYNT",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/Myntra_Logo.png/512px-Myntra_Logo.png",
            coinsRequired: 1200
        ),
        BrandCard(
            name: "Zomato",
            color: Color(red: 0.87, green: 0.10, blue: 0.10),
            codePrefix: "ZMTO",
            logoURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Zomato_logo.png/512px-Zomato_logo.png",
            coinsRequired: 1500
        )
    ]

    var body: some View {
        ScrollView {
        VStack(spacing: 16) {
                header
                dailyRewardCard
                gamesRow
                vouchersCarousel
                redeemToBankCard
                NavigationLink(destination: CoinActivityView()) {
                    HStack {
                        Text("View Coin Activity").font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Rewards")
        .sheet(item: $activeGame) { g in
            NavigationView {
                switch g.type {
                case .scratch:
                    ScratchCardGameView(entryFee: entryFee, winPrize: winPrize, title: g.title) { activeGame = nil }
                case .spin:
                    SpinWheelGameView(entryFee: entryFee, winPrize: winPrize, title: g.title) { activeGame = nil }
                case .ttt:
                    TicTacToeGameView(entryFee: entryFee, winPrize: winPrize, title: g.title) { activeGame = nil }
                }
            }
        }
        .sheet(item: $selectedBrand) { brand in
            VoucherRedeemSheet(brand: brand, balance: coinBalance) { coinsToSpend in
                Task { await redeemCoins(coinsToSpend, note: "Voucher \(brand.name)") }
            }
        }
        .sheet(isPresented: $showRedeemSheet) {
            BankRedeemSheet(maxRupeesPerDay: dailyCapRupees, balanceCoins: coinBalance) { rupees in
                let coins = rupees * 100
                Task { await redeemCoins(coins, note: "Bank redeem (test)") }
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .onAppear { listen() }
    }
    
    // MARK: - Sections
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Liquid Coins").font(.caption).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(coinBalance)").font(.system(size: 42, weight: .bold))
                Text("(\(coinValueInInr))").foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(12)
    }
    
    private var dailyRewardCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Reward").font(.headline)
                Spacer()
                if let next = dailyRewardNext { Text("Next: \(relative(next))").font(.caption).foregroundColor(.secondary) }
            }
            Text("Collect 5–10 coins once every 24h.").font(.subheadline).foregroundColor(.secondary)
            Button {
                Task { await claimDaily() }
            } label: {
                Text(canClaimDaily ? "Collect now" : "Collected")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canClaimDaily ? Color.accentColor : Color.gray.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!canClaimDaily)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var gamesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mini‑Games").font(.headline)
            Spacer()
                Text("Entry: \(entryFee) coins • Win: +\(winPrize)").font(.caption).foregroundColor(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(games) { g in
                        Button {
                            Task { @MainActor in
                                await showAdThen { activeGame = g }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(g.title).font(.headline).foregroundColor(.white)
                                Text("Tap to play").font(.caption).foregroundColor(.white.opacity(0.9))
                            }
                            .padding()
                            .frame(width: 180, height: 90, alignment: .leading)
                            .background(g.color)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    private var vouchersCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vouchers").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(brands) { brand in
                        Button {
                            Task { @MainActor in
                                await showAdThen {
                                    selectedBrand = brand
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                brand.color
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        AsyncImage(url: URL(string: brand.logoURL)) { phase in
                                            switch phase {
                                            case .empty: ProgressView().tint(.white)
                                            case .success(let image): image.resizable().scaledToFit()
                                            case .failure: Image(systemName: "giftcard").resizable().scaledToFit().foregroundColor(.white)
                                            @unknown default: EmptyView()
                                            }
                                        }
                                        .frame(width: 28, height: 28)
                                        Text(brand.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    Text("\(brand.coinsRequired) coins")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding(12)
                            }
                            .frame(width: 180, height: 90)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    private var redeemToBankCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Redeem to Bank (Test)").font(.headline)
            Text("Redeem up to ₹\(dailyCapRupees) per day").font(.caption).foregroundColor(.secondary)
            Button {
                showRedeemSheet = true
            } label: {
                Text("Redeem now")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(coinBalance < 1000)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Logic
    private var canClaimDaily: Bool { dailyRewardNext == nil || (dailyRewardNext ?? Date()) <= Date() }
    
    private func listen() {
        guard let uid = Auth.auth().currentUser?.uid else { isLoading = false; return }
        _ = RewardsService.shared.listenToBalanceAndEntries(uid: uid) { balance, _ in
            self.coinBalance = balance
            self.isLoading = false
        }
    }
    
    private func claimDaily() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let res = try await RewardsService.shared.awardDailyRewardIfEligible(uid: uid)
            if res.awarded == 0 { self.dailyRewardNext = res.nextEligibleAt } else { self.dailyRewardNext = Date(timeIntervalSinceNow: 24*3600); UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        } catch { self.errorMessage = error.localizedDescription }
    }
    
    private func redeemCoins(_ coins: Int, note: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await RewardsService.shared.redeemCoins(uid: uid, amount: coins, note: note); UINotificationFeedbackGenerator().notificationOccurred(.success) } catch { errorMessage = error.localizedDescription; UINotificationFeedbackGenerator().notificationOccurred(.error) }
    }
    
    private func relative(_ d: Date) -> String {
        let secs = Int(d.timeIntervalSinceNow)
        if secs <= 0 { return "now" }
        let h = secs/3600; let m = (secs%3600)/60
        if h > 0 { return "in \(h)h \(m)m" }
        return "in \(m)m"
    }
    
    // MARK: - Ad Integration
    @MainActor
    private func showAdThen(_ action: @escaping () -> Void) async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            action()
            return
        }
        // Find the topmost view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let shown = AdMobManager.shared.showInterstitialIfAvailable(from: topVC, onDismiss: action)
        if !shown { action() }
    }
}

// MARK: - Models & Sheets
private struct GameInfo: Identifiable { let id = UUID(); let title: String; let color: Color; let type: GameType }
private enum GameType { case scratch, spin, ttt }
private struct BrandCard: Identifiable { let id = UUID(); let name: String; let color: Color; let codePrefix: String; let logoURL: String; let coinsRequired: Int }

// GamesSheet replaced by native SwiftUI game views

private struct VoucherRedeemSheet: View {
    let brand: BrandCard
    let balance: Int
    var onRedeem: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var coinsText: String = "1000" // default
    @State private var code: String? = nil
    @FocusState private var isCoinsFieldFocused: Bool
    
    var coinsToSpend: Int {
        max(brand.coinsRequired, Int(coinsText) ?? brand.coinsRequired)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card with Brand
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: brand.logoURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                Image(systemName: "giftcard")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.white)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 64, height: 64)
                        .padding(.top, 8)
                        
                        Text("Redeem \(brand.name) Voucher")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Exchange your Liquid Coins for \(brand.name) voucher")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        LinearGradient(
                            colors: [brand.color, brand.color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    
                    // Coins Input Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter Coins to Spend")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            TextField("", text: $coinsText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .focused($isCoinsFieldFocused)
                                .frame(height: 60)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isCoinsFieldFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("coins")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                if coinsToSpend >= brand.coinsRequired {
                                    Text("≈ ₹\(coinsToSpend / 100)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .frame(width: 70, alignment: .leading)
                        }
                        
                        // Balance and Requirements
                        VStack(spacing: 12) {
                            HStack {
                                Text("Your Balance")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(balance) coins")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Minimum Required")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(brand.coinsRequired) coins")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(balance >= brand.coinsRequired ? .green : .orange)
                            }
                            
                            if coinsToSpend > balance {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Insufficient coins. You need \(coinsToSpend - balance) more coins.")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(16)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                    
                    // Generated Code Display
                    if let c = code {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Voucher Generated!")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            Text("Your Voucher Code")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            Text(c)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                                )
                        }
                        .padding(20)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(20)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            let coins = max(brand.coinsRequired, Int(coinsText) ?? brand.coinsRequired)
                            guard coins <= balance else { return }
                            onRedeem(coins)
                            code = "\(brand.codePrefix)-\(Int.random(in: 1000...9999))-\(Int.random(in: 1000...9999))"
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Text("Redeem Now")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: coinsToSpend <= balance ? [brand.color, brand.color.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: coinsToSpend <= balance ? brand.color.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(coinsToSpend > balance || coinsToSpend < brand.coinsRequired)
                        .opacity(coinsToSpend <= balance && coinsToSpend >= brand.coinsRequired ? 1.0 : 0.6)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .onAppear {
            coinsText = String(brand.coinsRequired)
        }
    }
}

private struct BankRedeemSheet: View {
    let maxRupeesPerDay: Int
    let balanceCoins: Int
    var onRedeem: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rupeesText: String = ""
    @State private var error: String? = nil
    @FocusState private var isAmountFieldFocused: Bool
    
    var rupeesToRedeem: Int {
        max(1, Int(rupeesText) ?? 0)
    }
    
    var coinsNeeded: Int {
        rupeesToRedeem * 100
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    VStack(spacing: 16) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                            .padding(.top, 8)
                        
                        Text("Redeem to Bank Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Convert your Liquid Coins to cash")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("(Test Mode)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    
                    // Amount Input Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter Amount to Redeem")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Text("₹")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            
                            TextField("", text: $rupeesText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .focused($isAmountFieldFocused)
                                .frame(height: 60)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isAmountFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                        
                        // Balance and Limits
                        VStack(spacing: 12) {
                            HStack {
                                Text("Your Coin Balance")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(balanceCoins) coins")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Coins Needed")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(coinsNeeded) coins")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(coinsNeeded <= balanceCoins ? .green : .orange)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Daily Limit")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("₹\(maxRupeesPerDay)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            
                            // Error Messages
                            if let e = error {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(e)
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            } else if rupeesToRedeem > maxRupeesPerDay {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Daily limit exceeded. Maximum ₹\(maxRupeesPerDay) per day.")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            } else if coinsNeeded > balanceCoins {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Insufficient coins. You need \(coinsNeeded - balanceCoins) more coins.")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(16)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            redeemTap()
                        } label: {
                            Text("Redeem Now")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: canRedeem ? [Color.blue, Color.blue.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: canRedeem ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!canRedeem)
                        .opacity(canRedeem ? 1.0 : 0.6)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    private var canRedeem: Bool {
        let rupees = max(1, Int(rupeesText) ?? 0)
        let needed = rupees * 100
        return rupees >= 1 && rupees <= maxRupeesPerDay && needed <= balanceCoins
    }
    
    private func redeemTap() {
        let rupees = max(1, Int(rupeesText) ?? 0)
        if rupees > maxRupeesPerDay {
            error = "Daily limit exceeded. Maximum ₹\(maxRupeesPerDay) per day."
            return
        }
        let needed = rupees * 100
        if needed > balanceCoins {
            error = "Insufficient coins. You need \(needed - balanceCoins) more coins."
            return
        }
        onRedeem(rupees)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}


