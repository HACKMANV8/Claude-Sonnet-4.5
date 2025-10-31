import SwiftUI
import FirebaseAuth

struct RewardsView: View {
    @State private var coinBalance: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showGame: Bool = false
    @State private var activeGame: GameInfo? = nil
    @State private var showVoucherSheet: Bool = false
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
        .sheet(isPresented: $showGame) {
            if let g = activeGame {
                NavigationView {
                    switch g.type {
                    case .scratch:
                        ScratchCardGameView(entryFee: entryFee, winPrize: winPrize, title: g.title) { showGame = false }
                    case .spin:
                        SpinWheelGameView(entryFee: entryFee, winPrize: winPrize, title: g.title) { showGame = false }
                    case .ttt:
                        TicTacToeGameView(entryFee: entryFee, winPrize: winPrize, title: g.title) { showGame = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showVoucherSheet) {
            if let brand = selectedBrand {
                VoucherRedeemSheet(brand: brand, balance: coinBalance) { coinsToSpend in
                    Task { await redeemCoins(coinsToSpend, note: "Voucher \(brand.name)") }
                }
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
                            activeGame = g
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showGame = true
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
                            selectedBrand = brand
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showVoucherSheet = true
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
    
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 44, height: 4).padding(.top, 8)
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: brand.logoURL)) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Image(systemName: "giftcard").resizable().scaledToFit()
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 28, height: 28)
                Text("Redeem \(brand.name)").font(.headline)
                Spacer()
            }
            TextField("Coins to spend", text: $coinsText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            HStack { Text("Balance: \(balance)").foregroundColor(.secondary); Spacer() }
            if let c = code { Text("Your code: \(c)").font(.headline).foregroundColor(.green) }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Redeem") {
                    let coins = max(100, Int(coinsText) ?? 0)
                    onRedeem(coins)
                    code = "\(brand.codePrefix)-\(Int.random(in: 1000...9999))-\(Int.random(in: 1000...9999))"
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear { coinsText = String(brand.coinsRequired) }
    }
}

private struct BankRedeemSheet: View {
    let maxRupeesPerDay: Int
    let balanceCoins: Int
    var onRedeem: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rupeesText: String = ""
    @State private var error: String? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4)).frame(width: 44, height: 4).padding(.top, 8)
            Text("Redeem to Bank (Test)").font(.headline)
            TextField("Amount (₹)", text: $rupeesText).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            if let e = error { Text(e).foregroundColor(.red).font(.caption) }
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Redeem") { redeemTap() }.buttonStyle(.borderedProminent) }
        }.padding()
    }
    private func redeemTap() {
        let rupees = max(1, Int(rupeesText) ?? 0)
        if rupees > maxRupeesPerDay { error = "Max ₹\(maxRupeesPerDay) per day"; return }
        let needed = rupees * 100
        if needed > balanceCoins { error = "Insufficient coins"; return }
        onRedeem(rupees)
        dismiss()
    }
}


