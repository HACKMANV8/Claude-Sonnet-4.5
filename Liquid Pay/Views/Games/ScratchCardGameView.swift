import SwiftUI
import FirebaseAuth

struct ScratchCardGameView: View {
    let entryFee: Int
    let winPrize: Int
    let title: String
    var onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var revealed: Bool = false
    @State private var win: Bool = Bool.random()
    @State private var charged: Bool = false
    @State private var confetti: Bool = false
    @State private var collected: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Entry: \(entryFee) • Win: +\(winPrize)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(20)

                // Scratch card area
                VStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 6)
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(win ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                                .overlay(
                                    Text(win ? "+\(winPrize)" : "Try again")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(win ? .green : .red)
                                )
                                .padding(16)
                            if !revealed {
                                ScratchOverlay(revealed: $revealed)
                                    .onAppear { Task { await chargeEntryIfNeeded() } }
                                    .padding(16)
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 260)

                    Text(revealed ? (win ? "You won +\(winPrize) coins" : "Better luck next time") : "Scratch to reveal your prize")
                        .font(.headline)
                        .foregroundColor(revealed ? (win ? .green : .red) : .secondary)
                        .padding(.top, 4)

                    if revealed && win {
                        Button(collected ? "Collected" : "Collect Reward") {
                            guard !collected else { return }
                            confetti = true
                            DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                                Task { await awardWin() }
                                collected = true
                            }
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: .green.opacity(0.25), radius: 8, x: 0, y: 4)
                        .disabled(collected)
                        .opacity(collected ? 0.7 : 1)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)

                Button("Close") { dismiss(); onClose() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(14)
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { GameConfettiView(isActive: $confetti, duration: 1.5, confettiCount: 50) }
    }
    
    private func chargeEntryIfNeeded() async {
        guard !charged, let uid = Auth.auth().currentUser?.uid else { return }
        do { try await RewardsService.shared.chargeGameEntry(uid: uid, fee: entryFee, game: title); charged = true } catch { }
    }
    private func awardWin() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await RewardsService.shared.awardGameWin(uid: uid, prize: winPrize, game: title) } catch { }
    }
}

private struct ScratchOverlay: View {
    @Binding var revealed: Bool
    @State private var maskPath = Path()
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.gray)
                .overlay(Text("SCRATCH").font(.headline).foregroundColor(.white))
                .mask(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(Color.white)
                        maskPath.stroke(lineWidth: 40).blendMode(.destinationOut)
                    }
                )
        }
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            let pt = value.location
            if maskPath.isEmpty { maskPath.move(to: pt) } else { maskPath.addLine(to: pt) }
        }.onEnded { _ in
            revealed = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        })
        .compositingGroup()
    }
}


