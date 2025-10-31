import SwiftUI
import UIKit
import FirebaseAuth

struct PaymentSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let payment: Payment
    let payeeName: String?
    let coinsEarned: Int
    
    @State private var showCheckmark = false
    @State private var showContent = false
    @State private var showConfetti = false
    @State private var showShareSheet = false
    @State private var pulseAnimation = false
    @State private var pendingReward: ContextReward? = nil
    @State private var rewardListener: ListenerRegistration? = nil
    @State private var isClaiming: Bool = false
    @State private var showVoucherSheet: Bool = false
    @State private var suggestedBrand: String? = nil
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)
                    
                    // Success Animation
                    ZStack {
                        // Pulsing circles
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .opacity(pulseAnimation ? 0 : 1)
                        
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 160, height: 160)
                            .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                            .opacity(pulseAnimation ? 0 : 1)
                        
                        // Checkmark circle
                        Circle()
                            .fill(Color.green)
                            .frame(width: 120, height: 120)
                            .scaleEffect(showCheckmark ? 1.0 : 0.3)
                            .opacity(showCheckmark ? 1 : 0)
                        
                        // Checkmark icon
                        Image(systemName: "checkmark")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(showCheckmark ? 1.0 : 0.3)
                            .opacity(showCheckmark ? 1 : 0)
                            .rotationEffect(.degrees(showCheckmark ? 0 : -90))
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showCheckmark = true
                        }
                        
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            pulseAnimation = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showContent = true
                            }
                            showConfetti = true
                        }
                    }
                    
                    // Success message
                    VStack(spacing: 8) {
                        Text("Payment Successful!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Your payment has been processed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // Amount card
                    VStack(spacing: 16) {
                        Text(Currency.formatPaise(payment.amountPaise))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.green)
                        
                        // Coins earned badge
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Earned \(coinsEarned) Liquid Coins")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.15))
                        .cornerRadius(20)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                    // Context Mission card (if any)
                    if let reward = pendingReward {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(reward.title)
                                    .font(.headline)
                                Spacer()
                                Text("+\(reward.coins) coins")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            Text(reward.reason)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button {
                                claimContextReward(reward)
                            } label: {
                                HStack {
                                    Image(systemName: "star.fill")
                                    Text(isClaiming ? "Claiming..." : "Claim +\(reward.coins) coins")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isClaiming)

                            if let brand = suggestedBrand {
                                Button {
                                    showVoucherSheet = true
                                } label: {
                                    HStack {
                                        Image(systemName: "giftcard")
                                        Text("Redeem coins for \(brand) voucher")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.tertiarySystemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    }
                    
                    // Payment details
                    VStack(spacing: 16) {
                        DetailRow(
                            icon: "person.fill",
                            label: "Payee",
                            value: payeeName ?? "Unknown"
                        )
                        
                        Divider()
                        
                        DetailRow(
                            icon: "person.circle.fill",
                            label: "Payer",
                            value: Auth.auth().currentUser?.email ?? "You"
                        )
                        
                        Divider()
                        
                        DetailRow(
                            icon: "calendar",
                            label: "Date",
                            value: (payment.createdAt ?? Date()).formatted(date: .abbreviated, time: .shortened)
                        )
                        
                        Divider()
                        
                        DetailRow(
                            icon: "number",
                            label: "Transaction ID",
                            value: payment.id
                        )
                        
                        if let razorpayId = payment.razorpayPaymentId {
                            Divider()
                            
                            DetailRow(
                                icon: "creditcard.fill",
                                label: "Payment ID",
                                value: razorpayId
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Receipt")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24)
            }
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    NotificationCenter.default.post(name: .paymentCompleted, object: nil)
                    NotificationCenter.default.post(name: .switchTab, object: nil, userInfo: ["index": 0])
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Home")
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [generateShareText()])
        }
        .onAppear {
            // Listen to Firestore context reward for this payment
            if let uid = Auth.auth().currentUser?.uid {
                rewardListener?.remove(); rewardListener = nil
                rewardListener = RewardsService.shared.listenToContextReward(uid: uid, paymentId: payment.id) { reward in
                    self.pendingReward = reward
                }
            }
            // Infer e‑com brand from payee for voucher nudge
            let rec = (payeeName ?? "").lowercased()
            if rec.contains("flipkart") { suggestedBrand = "Flipkart" }
            else if rec.contains("amazon") { suggestedBrand = "Amazon" }
            else if rec.contains("myntra") { suggestedBrand = "Myntra" }
            else { suggestedBrand = nil }
        }
        .onDisappear { rewardListener?.remove(); rewardListener = nil }
        .sheet(isPresented: $showVoucherSheet) {
            if let brand = suggestedBrand {
                QuickVoucherSheet(brand: brand, balanceCoins: nil) { coins in
                    Task { @MainActor in
                        guard let uid = Auth.auth().currentUser?.uid else { return }
                        try? await RewardsService.shared.redeemCoins(uid: uid, amount: coins, note: "Voucher \(brand)")
                    }
                }
            }
        }
    }
    
    private func generateShareText() -> String {
        var text = "✅ Payment Successful!\n\n"
        text += "💰 Amount: \(Currency.formatPaise(payment.amountPaise))\n"
        if let payee = payeeName {
            text += "👤 Paid to: \(payee)\n"
        }
        if let date = payment.createdAt {
            text += "📅 Date: \(date.formatted(date: .abbreviated, time: .shortened))\n"
        }
        text += "🆔 Transaction ID: \(payment.id)\n"
        text += "\n⭐ Earned \(coinsEarned) Liquid Coins!\n"
        text += "\nPowered by Liquid Pay 💧"
        return text
    }
}

// MARK: - Context Reward Claim
extension PaymentSuccessView {
    private func claimContextReward(_ reward: ContextReward) {
        guard !isClaiming else { return }
        isClaiming = true
        Task { @MainActor in
            defer { self.isClaiming = false }
            guard let uid = Auth.auth().currentUser?.uid else { return }
            do {
                try await RewardsService.shared.claimContextReward(uid: uid, paymentId: reward.paymentId)
                // Celebration
                self.showConfetti = true
            } catch {
                // no-op demo error handling
            }
        }
    }
}

// MARK: - Quick Voucher Sheet (inline, minimal)
private struct QuickVoucherSheet: View {
    let brand: String
    let balanceCoins: Int?
    var onRedeem: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var coinsText: String = "1000"
    @State private var code: String? = nil

    var coinsToSpend: Int { max(1, Int(coinsText) ?? 0) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Redeem \(brand) Voucher").font(.title2).bold()
                        Text("Exchange coins for a \(brand) code").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter Coins").font(.headline)
                        TextField("1000", text: $coinsText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        if let bal = balanceCoins {
                            HStack { Text("Balance"); Spacer(); Text("\(bal) coins") }.foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(16)

                    if let c = code {
                        VStack(spacing: 8) {
                            Text("Voucher Generated!").font(.headline).foregroundColor(.green)
                            Text(c).font(.system(size: 22, weight: .bold, design: .monospaced))
                                .padding().background(Color(.secondarySystemBackground)).cornerRadius(10)
                        }
                    }

                    Button {
                        onRedeem(coinsToSpend)
                        code = "\(brand.prefix(3).uppercased())-\(Int.random(in: 1000...9999))-\(Int.random(in: 1000...9999))"
                    } label: {
                        Text("Redeem Now")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button { dismiss() } label: {
                        Text("Close").frame(maxWidth: .infinity).padding()
                            .background(Color(.secondarySystemBackground)).cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Detail Row Component
private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
        }
    }
}

// MARK: - Confetti Animation
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiShape()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .position(x: piece.x, y: piece.y)
                        .rotationEffect(.degrees(piece.rotation))
                        .opacity(piece.opacity)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
            }
        }
    }
    
    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
        
        for _ in 0..<50 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: -50,
                size: CGFloat.random(in: 8...15),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
            confettiPieces.append(piece)
            
            withAnimation(.easeIn(duration: Double.random(in: 2...4))) {
                if let index = confettiPieces.firstIndex(where: { $0.id == piece.id }) {
                    confettiPieces[index].y = size.height + 50
                    confettiPieces[index].rotation += 720
                    confettiPieces[index].opacity = 0
                }
            }
        }
        
        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            confettiPieces.removeAll()
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var rotation: Double
    var opacity: Double
}

struct ConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}

// MARK: - ShareSheet
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

